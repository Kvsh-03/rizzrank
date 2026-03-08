/**
 * RTDB trigger: when a user sends a message (matches/{matchId}/players/{playerId}/messages/{messageId}).
 * Runs the AI pipeline: load match, get AI response, judge, update vibe, check win.
 * Replaces Firestore onUserMessageSent for active matches.
 */

import * as admin from "firebase-admin";
import { ServerValue } from "firebase-admin/database";
import { onValueCreated } from "firebase-functions/v2/database";
import { getAIResponse, WIN_THRESHOLD } from "./geminiChatService";
import { scoreMessage, getTimingMult, computeTurnScore } from "./geminiJudge";
import { finalizeMatch } from "./finalizeMatch";

const db = admin.firestore();
const rtdb = admin.database();

function resolveApiKey(): string {
  try {
    const { defineString } = require("firebase-functions/params");
    const geminiKey = defineString("GEMINI_API_KEY");
    const val = geminiKey.value();
    if (val && val !== "") return val;
  } catch {
    // defineString not available in emulator
  }
  return process.env.GEMINI_API_KEY || "mock";
}

export const onRTDBMessageSent = onValueCreated(
  "/matches/{matchId}/players/{playerId}/messages/{messageId}",
  async (event) => {
    const data = event.data.val();
    if (!data || data.role !== "user") return;

    const matchId = event.params.matchId;
    const playerId = event.params.playerId;
    const userText = (data.content as string) || (data.text as string) || "";

    if (!userText) return;

    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
      console.error(`Match ${matchId} not found`);
      return;
    }
    const matchData = matchDoc.data()!;
    if (matchData.status !== "active") return;

    const characterId = (matchData.ai_character_id as string) || "luna";
    const playerIds: string[] = matchData.player_ids || [];
    const aiTraits: Record<string, string> =
      (matchData.ai_traits as Record<string, string>) ?? {};
    const systemPromptOverride = matchData.ai_system_prompt as string | undefined;
    const characterNameOverride = matchData.ai_character_name as string | undefined;

    const playerIndex = playerIds.indexOf(playerId);
    if (playerIndex === -1) return;

    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe: number = vibeSnap.val() ?? 0;

    const messagesRef = rtdb.ref(`matches/${matchId}/players/${playerId}/messages`);
    const messagesSnap = await messagesRef.orderByChild("timestamp").get();

    interface MergedMsg { role: string; text: string; _ts: number }
    const allMsgs: MergedMsg[] = [];
    if (messagesSnap.exists() && messagesSnap.val()) {
      const val = messagesSnap.val() as Record<string, { role?: string; content?: string; text?: string; timestamp?: number }>;
      for (const [k, v] of Object.entries(val)) {
        const ts = (v.timestamp as number) ?? 0;
        allMsgs.push({
          role: (v.role as string) || "user",
          text: (v.content as string) || (v.text as string) || "",
          _ts: ts,
        });
      }
    }
    allMsgs.sort((a, b) => a._ts - b._ts);

    const history = allMsgs.map((d) => ({
      role: d.role as "user" | "model",
      text: d.text,
    }));

    const lastAIMsg = [...allMsgs].reverse().find((d) => d.role === "model")?.text ?? "";
    const lastAITimestamp = [...allMsgs].reverse().find((d) => d.role === "model")?._ts ?? 0;
    const userMsgTimestamp = (data.timestamp as number) ?? Date.now();
    const responseTimeSec = lastAITimestamp > 0
      ? (userMsgTimestamp - lastAITimestamp) / 1000
      : 4.0;

    const typingRef = rtdb.ref(`active_states/${matchId}/is_typing/ai_${playerId}`);
    await typingRef.set(true);

    const apiKey = resolveApiKey();

    try {
      let aiResult;
      let scoringResult;
      let turnResult;
      let aiError = false;

      try {
        aiResult = await getAIResponse(
          apiKey,
          characterId,
          history,
          currentVibe,
          aiTraits,
          systemPromptOverride,
          characterNameOverride
        );

        scoringResult = await scoreMessage(
          apiKey, characterId, lastAIMsg, userText, aiTraits
        );
      } catch (error) {
        console.error(`[${matchId}] Gemini API Error:`, error);
        aiError = true;
        aiResult = {
          text: "[System: AI is currently unavailable.]",
          isDateAsk: false,
        };
        scoringResult = {
          baseGood: 5,
          baseBad: 0,
          personaMult: 1.0,
          reasoning: "Fallback due to AI error.",
        };
      }

      const timingMult = getTimingMult(responseTimeSec);
      turnResult = computeTurnScore(scoringResult, timingMult);

      await rtdb.ref(`matches/${matchId}/players/${playerId}/messages`).push({
        role: "model",
        content: aiResult.text,
        sender_uid: `ai_${characterId}`,
        timestamp: ServerValue.TIMESTAMP,
        rizz_delta: aiError ? 0 : null,
      });

      let updatedVibe = currentVibe;
      if (!aiError) {
        const newVibe = await vibeRef.transaction((current: number | null) => {
          return (current ?? 0) + turnResult.turnScore;
        });
        updatedVibe = (newVibe.snapshot.val() as number) ?? currentVibe + turnResult.turnScore;
      }

      const messageRef = event.data.ref;
      await messageRef.update({
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
        `[${matchId}] ${playerId} (${vibeKey}): +${aiError ? 0 : turnResult.turnScore} rizz → ${updatedVibe}` +
        (aiResult.isDateAsk ? " ★ DATE ASK" : "")
      );

      if (!aiError && aiResult.isDateAsk && updatedVibe > WIN_THRESHOLD) {
        console.log(`[${matchId}] WINNER: ${playerId}`);
        await finalizeMatch({ matchId, winnerUid: playerId, playerIds });
      }
    } finally {
      await typingRef.remove();
    }
  }
);
