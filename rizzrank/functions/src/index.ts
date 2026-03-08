/**
 * RizzRank Date Race - Cloud Functions
 *
 * Exports:
 *   - onUserMessageSent: Firestore trigger on matches/{matchId}/players/{playerId}/messages/{messageId}
 *   - findMatch, leaveQueue: HTTPS callables for matchmaking
 *   - cleanupExpiredMatchmaking: Scheduled cleanup
 *   - checkMatchTimeouts: Scheduled match timeout enforcement
 *
 * Pipeline (onUserMessageSent):
 *   1. Read AI character from Firestore ai_models collection (fallback to hardcoded)
 *   2. Gemini 2.0 Flash generates AI reply
 *   3. Gemini Flash-Lite judges the user message (Turn Score formula)
 *   4. RTDB active_states/{matchId}/p1_vibe or p2_vibe is updated
 *   5. If vibe > 100 and date-ask detected: finalizeMatch is called
 *
 * Scoring formula:
 *   Turn Score = [(Base Good x Persona Mult) x Timing Mult] - Base Bad
 */

import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineString } from "firebase-functions/params";
import { getAIResponse, WIN_THRESHOLD } from "./geminiChatService";
import { scoreMessage, getTimingMult, computeTurnScore } from "./geminiJudge";
import { getCharacter } from "./characters";
import { finalizeMatch, drawMatch } from "./finalizeMatch";

admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

const geminiKey = defineString("GEMINI_API_KEY");

// Helper: resolve the API key, falling back to env var or "mock" in emulators
function resolveApiKey(): string {
  try {
    return geminiKey.value();
  } catch {
    return process.env.GEMINI_API_KEY || "mock";
  }
}

// Re-export matchmaking callables
export { findMatch, leaveQueue } from "./matchmaking";

// ─────────────────────────────────────────────────────────────────────────────
// Helper: load AI character from Firestore ai_models, falling back to hardcoded
// ─────────────────────────────────────────────────────────────────────────────
interface AICharacterConfig {
  systemInstruction: string;
  description: string;
}

async function loadCharacter(characterId: string): Promise<AICharacterConfig> {
  const doc = await db.doc(`ai_models/${characterId}`).get();
  if (doc.exists) {
    const data = doc.data()!;
    return {
      systemInstruction: (data.system_prompt as string) ?? "",
      description: (data.personality_summary as string) ?? "",
    };
  }
  const fallback = getCharacter(characterId);
  return {
    systemInstruction: fallback.systemInstruction,
    description: fallback.description,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Firestore trigger: matches/{matchId}/chat/{messageId}
// Fires when any new message is added to the chat subcollection.
// Only processes messages where role === "user".
// ─────────────────────────────────────────────────────────────────────────────
export const onUserMessageSent = onDocumentCreated(
  "matches/{matchId}/players/{playerId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (!data || data.role !== "user") return;

    const matchId = event.params.matchId;
    const playerId = event.params.playerId;
    const messageId = event.params.messageId;
    const senderUid = (data.sender_uid as string) || playerId;
    const userText = (data.content as string) || (data.text as string) || "";

    if (!userText) {
      console.warn(`Missing content on ${matchId}/players/${playerId}/messages/${messageId}`);
      return;
    }

    // ── Read match metadata ──────────────────────────────────────────────
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
      console.error(`Match ${matchId} not found`);
      return;
    }
    const matchData = matchDoc.data()!;
    if (matchData.status !== "active") {
      console.warn(`Match ${matchId} status is '${matchData.status}', ignoring message`);
      return;
    }
    const characterId = (matchData.ai_character_id as string) || "luna";
    const playerIds: string[] = matchData.player_ids || [];
    const aiTraits: Record<string, string> =
      (matchData.ai_traits as Record<string, string>) ?? {};

    const playerIndex = playerIds.indexOf(playerId);
    if (playerIndex === -1) {
      console.error(`Player ${playerId} not in match ${matchId} players`);
      return;
    }
    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";

    // ── Load AI character config ─────────────────────────────────────────
    const charConfig = await loadCharacter(characterId);

    // ── Read current vibe from RTDB ──────────────────────────────────────
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe: number = vibeSnap.val() ?? 0;

    // ── Build chat history from player's private shard ──────────────────
    const chatSnap = await db
      .collection(`matches/${matchId}/players/${playerId}/messages`)
      .orderBy("timestamp", "asc")
      .get();

    interface MergedMsg { role: string; text: string; _ts: number }
    const allDocs: MergedMsg[] = chatSnap.docs
      .map((d) => {
        const dd = d.data();
        return {
          role: (dd.role as string) || "user",
          text: (dd.content as string) || (dd.text as string) || "",
          _ts: dd.timestamp?.toMillis?.() ?? 0,
        };
      })
      .sort((a, b) => a._ts - b._ts);

    const history = allDocs.map((d) => ({
      role: d.role as "user" | "model",
      text: d.text,
    }));

    const lastAIMsg =
      [...allDocs].reverse().find((d) => d.role === "model")?.text ?? "";

    // ── Compute response time for timing multiplier ──────────────────────
    const lastAITimestamp = [...allDocs]
      .reverse()
      .find((d) => d.role === "model")?._ts ?? 0;
    const userMsgTimestamp = data.timestamp?.toMillis?.() ?? Date.now();
    const responseTimeSec = lastAITimestamp > 0
      ? (userMsgTimestamp - lastAITimestamp) / 1000
      : 4.0; // Default to sweet spot for the first message

    // ── Set AI typing indicator in RTDB ──────────────────────────────────
    const typingRef = rtdb.ref(`active_states/${matchId}/is_typing/ai_${playerId}`);
    await typingRef.set(true);

    const apiKey = resolveApiKey();

    try {
      // ── Get AI response via Gemini ─────────────────────────────────────
      let aiResult;
      let scoringResult;
      let turnResult;
      let aiError = false;

      try {
        aiResult = await getAIResponse(
          apiKey, characterId, history, currentVibe, aiTraits, charConfig.systemInstruction
        );

        // ── Score the user message via Gemini Judge ────────────────────────
        scoringResult = await scoreMessage(
          apiKey, characterId, lastAIMsg, userText, aiTraits
        );
      } catch (error) {
        console.error(`[${matchId}] Gemini API Error:`, error);
        aiError = true;
        // Graceful fallback if Gemini API fails (e.g., invalid key, quota exceeded)
        aiResult = {
          text: "[System: AI is currently unavailable or the API key is invalid.]",
          isDateAsk: false,
        };
        scoringResult = {
          baseGood: 5, // Neutral score
          baseBad: 0,
          personaMult: 1.0,
          reasoning: "Fallback score due to AI generation error.",
        };
      }

      // ── Apply Turn Score formula ───────────────────────────────────────
      const timingMult = getTimingMult(responseTimeSec);
      turnResult = computeTurnScore(scoringResult, timingMult);

      // ── Write AI reply to player's private shard ───────────────────────
      await db.collection(`matches/${matchId}/players/${playerId}/messages`).add({
        role: "model",
        content: aiResult.text,
        sender_uid: `ai_${characterId}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        rizz_delta: aiError ? 0 : null, // Indicate error in rizz_delta if needed
      });

      // ── Update vibe in RTDB via transaction (atomic increment) ─────────
      let updatedVibe = currentVibe;
      if (!aiError) {
        const newVibe = await vibeRef.transaction((current: number | null) => {
          return (current ?? 0) + turnResult.turnScore;
        });
        updatedVibe = (newVibe.snapshot.val() as number) ?? currentVibe + turnResult.turnScore;
      }

      // ── Write scoring breakdown back onto the original user message ────
      await snap.ref.update({
        rizz_delta: aiError ? 0 : turnResult.turnScore,
        scoring: {
          base_good: turnResult.baseGood,
          base_bad: turnResult.baseBad,
          persona_mult: turnResult.personaMult,
          timing_mult: turnResult.timingMult,
          reasoning: turnResult.reasoning,
        },
      });

      console.log(
        `[${matchId}] ${playerId} (${vibeKey}): ` +
        `+${aiError ? 0 : turnResult.turnScore} rizz (good=${turnResult.baseGood} ×persona=${turnResult.personaMult} ` +
        `×timing=${turnResult.timingMult} −bad=${turnResult.baseBad}) ` +
        `→ ${updatedVibe} total` +
        (aiResult.isDateAsk ? " ★ DATE ASK DETECTED" : "")
      );

      // ── Win detection: if AI asked for a date, finalize the match ──────
      if (!aiError && aiResult.isDateAsk && updatedVibe > WIN_THRESHOLD) {
        console.log(`[${matchId}] WINNER: ${playerId}`);
        await finalizeMatch({ matchId, winnerUid: playerId, playerIds });
      }
    } finally {
      // ── Always clear the AI typing indicator ───────────────────────────
      await typingRef.remove();
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled: cleanup expired matchmaking entries every 5 minutes
// ─────────────────────────────────────────────────────────────────────────────
export const cleanupExpiredMatchmaking = onSchedule("every 5 minutes", async () => {
  const now = Date.now();
  const expired = await db
    .collection("matchmaking")
    .where("expire_at", "<", now)
    .get();

  if (expired.empty) {
    console.log("[cleanup] No expired matchmaking entries");
    return;
  }

  const batch = db.batch();
  for (const doc of expired.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  console.log(`[cleanup] Removed ${expired.size} expired matchmaking entries`);
});

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled: enforce match timeouts every minute.
// If a match has expired, the player with the higher vibe wins.
// On a tie, it's a draw with no ELO change.
// ─────────────────────────────────────────────────────────────────────────────
export const checkMatchTimeouts = onSchedule("every 1 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const expired = await db
    .collection("matches")
    .where("status", "==", "active")
    .where("expires_at", "<=", now)
    .limit(20)
    .get();

  if (expired.empty) {
    return;
  }

  console.log(`[timeout] Processing ${expired.size} expired matches`);

  for (const matchDoc of expired.docs) {
    const data = matchDoc.data();
    const matchId = matchDoc.id;
    const playerIds: string[] = data.player_ids || [];

    if (playerIds.length < 2) {
      console.warn(`[timeout] Match ${matchId} has fewer than 2 players, skipping`);
      continue;
    }

    try {
      const stateSnap = await rtdb.ref(`active_states/${matchId}`).get();
      const state = stateSnap.val();
      const p1Vibe: number = state?.p1_vibe ?? 0;
      const p2Vibe: number = state?.p2_vibe ?? 0;

      if (p1Vibe > p2Vibe) {
        console.log(`[timeout] ${matchId}: P1 wins by meter (${p1Vibe} vs ${p2Vibe})`);
        await finalizeMatch({ matchId, winnerUid: playerIds[0], playerIds });
        await matchDoc.ref.update({ status: "timed_out" });
        await rtdb.ref(`active_states/${matchId}`).update({ status: "timed_out" });
      } else if (p2Vibe > p1Vibe) {
        console.log(`[timeout] ${matchId}: P2 wins by meter (${p2Vibe} vs ${p1Vibe})`);
        await finalizeMatch({ matchId, winnerUid: playerIds[1], playerIds });
        await matchDoc.ref.update({ status: "timed_out" });
        await rtdb.ref(`active_states/${matchId}`).update({ status: "timed_out" });
      } else {
        console.log(`[timeout] ${matchId}: Draw (both at ${p1Vibe})`);
        await drawMatch(matchId, playerIds);
      }
    } catch (err) {
      console.error(`[timeout] Error processing match ${matchId}:`, err);
    }
  }
});
