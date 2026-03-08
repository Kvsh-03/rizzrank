/**
 * Load .env from functions directory (for emulator/local).
 * Production uses Firebase secrets via defineString; .env is ignored when absent.
 */
import * as path from "path";
import { config } from "dotenv";
config({ path: path.resolve(__dirname, "../.env") });
config({ path: path.resolve(__dirname, "../.env.local") });

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
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AI_CHARACTERS } from "./characters";
import { finalizeMatch, drawMatch } from "./finalizeMatch";

admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

// Re-export matchmaking callables and matcher trigger
export { joinQueue, leaveQueue } from "./matchmaking";
export { onQueueWrite } from "./matchmakingMatcher";

// Re-export RTDB message trigger (replaces Firestore onUserMessageSent)
export { onRTDBMessageSent } from "./onRTDBMessageSent";

// Re-export presence trigger: when user goes offline, forfeit their active match
export { onPresenceOffline } from "./onPresenceOffline";

// ─────────────────────────────────────────────────────────────────────────────
// Forfeit: caller voluntarily ends match; opponent wins.
// ─────────────────────────────────────────────────────────────────────────────
export const forfeitMatch = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to forfeit.");
  }
  const matchId = request.data?.matchId as string | undefined;
  if (!matchId || typeof matchId !== "string") {
    throw new HttpsError("invalid-argument", "matchId is required.");
  }

  const callerUid = request.auth.uid;
  const matchDoc = await db.doc(`matches/${matchId}`).get();
  if (!matchDoc.exists) {
    throw new HttpsError("not-found", "Match not found.");
  }
  const matchData = matchDoc.data()!;
  if (matchData.status !== "active") {
    throw new HttpsError("failed-precondition", "Match is no longer active.");
  }
  const playerIds: string[] = matchData.player_ids || [];
  if (!playerIds.includes(callerUid)) {
    throw new HttpsError("permission-denied", "You are not in this match.");
  }
  const opponentUid = playerIds.find((id) => id !== callerUid);
  if (!opponentUid) {
    throw new HttpsError("internal", "Could not determine opponent.");
  }

  await finalizeMatch({ matchId, winnerUid: opponentUid, playerIds });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// One-time seed: seedAiModels callable. Invoke once to populate ai_models.
// Run from Flutter: FirebaseFunctions.instance.httpsCallable('seedAiModels').call()
// ─────────────────────────────────────────────────────────────────────────────
export const seedAiModels = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to seed.");
  }
  const batch = db.batch();
  for (const char of AI_CHARACTERS) {
    const ref = db.collection("ai_models").doc(char.id);
    batch.set(ref, {
      name: char.name,
      personality_summary: char.description,
      system_prompt: char.systemInstruction,
      role: char.role,
      avatar_url: char.avatar,
      difficulty: char.difficulty,
      gender: char.gender,
    });
  }
  await batch.commit();
  return { success: true, count: AI_CHARACTERS.length };
});

// ─────────────────────────────────────────────────────────────────────────────
// One-time seed: seedTraits callable. Populates traits/{category} with values.
// ─────────────────────────────────────────────────────────────────────────────
export const seedTraits = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to seed.");
  }
  const { TRAIT_DATA } = await import("./traitData");
  const batch = db.batch();
  const categories = Object.keys(TRAIT_DATA);
  for (const category of categories) {
    const ref = db.collection("traits").doc(category);
    batch.set(ref, { values: TRAIT_DATA[category] });
  }
  await batch.commit();
  return { success: true, count: categories.length };
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
