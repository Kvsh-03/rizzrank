/**
 * RizzRank Date Race - Cloud Functions
 *
 * Trigger: onUserMessageSent - fires on Firestore writes to matches/{matchId}/chat
 * Pipeline:
 *   1. OpenRouter (Llama 3.1 70B) generates AI reply
 *   2. Gemini Flash-Lite judges the user message (0-15 rizz score)
 *   3. RTDB active_states/{matchId}/p1_vibe or p2_vibe is updated
 *   4. If vibe > 100: win instruction injected, date-ask detection triggers match end
 */

import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineString } from "firebase-functions/params";
import { getAIResponse, WIN_THRESHOLD } from "./openRouterService";
import { scoreMessage } from "./geminiJudge";

admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

const openrouterKey = defineString("OPENROUTER_API_KEY");
const geminiKey = defineString("GEMINI_API_KEY");

// ─────────────────────────────────────────────────────────────────────────────
// Firestore trigger: matches/{matchId}/chat/{messageId}
// Fires when any new message is added to the chat subcollection.
// Only processes messages where role === "user".
// ─────────────────────────────────────────────────────────────────────────────
export const onUserMessageSent = onDocumentCreated(
  "matches/{matchId}/chat/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (!data || data.role !== "user") return;

    const matchId = event.params.matchId;
    const messageId = event.params.messageId;
    const senderUid = data.sender_uid as string;
    const userText = data.text as string;

    if (!senderUid || !userText) {
      console.warn(`Missing sender_uid or text on ${matchId}/chat/${messageId}`);
      return;
    }

    // ── Read match metadata ──────────────────────────────────────────────
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
      console.error(`Match ${matchId} not found`);
      return;
    }
    const matchData = matchDoc.data()!;
    const characterId = (matchData.ai_character_id as string) || "luna";
    const playerIds: string[] = matchData.player_ids || [];

    // Determine if sender is p1 or p2 (by position in player_ids array)
    const playerIndex = playerIds.indexOf(senderUid);
    if (playerIndex === -1) {
      console.error(`Sender ${senderUid} not in match ${matchId} players`);
      return;
    }
    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";

    // ── Read current vibe from RTDB ──────────────────────────────────────
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe: number = vibeSnap.val() ?? 0;

    // ── Build chat history from Firestore (this player's messages only) ──
    const chatSnap = await db
      .collection(`matches/${matchId}/chat`)
      .where("sender_uid", "==", senderUid)
      .orderBy("timestamp", "asc")
      .get();

    // Also get AI replies to this player
    const aiRepliesSnap = await db
      .collection(`matches/${matchId}/chat`)
      .where("target_uid", "==", senderUid)
      .where("role", "==", "model")
      .orderBy("timestamp", "asc")
      .get();

    // Merge and sort all messages for this player's conversation lane
    interface MergedMsg { role: string; text: string; _ts: number }
    const allDocs: MergedMsg[] = [...chatSnap.docs, ...aiRepliesSnap.docs]
      .map((d) => {
        const dd = d.data();
        return {
          role: (dd.role as string) || "user",
          text: (dd.text as string) || "",
          _ts: dd.timestamp?.toMillis?.() ?? 0,
        };
      })
      .sort((a, b) => a._ts - b._ts);

    const history = allDocs.map((d) => ({
      role: d.role as "user" | "model",
      text: d.text,
    }));

    // Find the last AI message for judge context
    const lastAIMsg =
      [...allDocs].reverse().find((d) => d.role === "model")?.text ?? "";

    // ── Run OpenRouter + Gemini Judge in parallel ────────────────────────
    const [aiResult, rizzDelta] = await Promise.all([
      getAIResponse(openrouterKey.value(), characterId, history, currentVibe),
      scoreMessage(geminiKey.value(), characterId, lastAIMsg, userText),
    ]);

    // ── Write AI reply to Firestore chat subcollection ───────────────────
    await db.collection(`matches/${matchId}/chat`).add({
      role: "model",
      text: aiResult.text,
      sender_uid: `ai_${characterId}`,
      target_uid: senderUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      rizz_delta: null,
    });

    // ── Update vibe in RTDB via transaction (atomic increment) ───────────
    const newVibe = await vibeRef.transaction((current: number | null) => {
      return (current ?? 0) + rizzDelta;
    });
    const updatedVibe =
      (newVibe.snapshot.val() as number) ?? currentVibe + rizzDelta;

    // ── Write rizz_delta back onto the original user message ─────────────
    await snap.ref.update({ rizz_delta: rizzDelta });

    console.log(
      `[${matchId}] ${senderUid} (${vibeKey}): +${rizzDelta} rizz → ${updatedVibe} total` +
        (aiResult.isDateAsk ? " ★ DATE ASK DETECTED" : "")
    );

    // ── Win detection: if AI asked for a date, finalize the match ────────
    if (aiResult.isDateAsk && updatedVibe > WIN_THRESHOLD) {
      console.log(`[${matchId}] WINNER: ${senderUid}`);

      // Update Firestore match document
      await db.doc(`matches/${matchId}`).update({
        status: "completed",
        winner_id: senderUid,
      });

      // Update RTDB active state
      await rtdb.ref(`active_states/${matchId}`).update({
        status: "completed",
        winner_uid: senderUid,
      });

      // Update player ELO in Firestore
      const winnerRef = db.doc(`users/${senderUid}`);
      await winnerRef.update({
        elo_rating: admin.firestore.FieldValue.increment(25),
        wins: admin.firestore.FieldValue.increment(1),
        total_games: admin.firestore.FieldValue.increment(1),
      });

      // Update loser ELO
      const loserUid = playerIds.find((id) => id !== senderUid);
      if (loserUid) {
        const loserRef = db.doc(`users/${loserUid}`);
        await loserRef.update({
          elo_rating: admin.firestore.FieldValue.increment(-12),
          losses: admin.firestore.FieldValue.increment(1),
          total_games: admin.firestore.FieldValue.increment(1),
        });
      }
    }
  }
);
