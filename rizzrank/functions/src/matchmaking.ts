/**
 * RTDB-based matchmaking: joinQueue, leaveQueue, and findMatch.
 *
 * Global queue structure: matchmaking_queue/{uid}
 * Index for preference lookup: matchmaking_queue_index/{uid}
 *
 * Matching is triggered by onQueueWrite in matchmakingMatcher.ts.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const QUEUE_TTL_MS = 5 * 60 * 1000; // 5 minutes

const PREFERENCES = ["Man", "Woman", "Other", "Any"] as const;

function getDefaultPreferredGender(gender: string | null): string {
  if (!gender) return "Woman"; // fallback
  return gender === "Man" ? "Woman" : gender === "Woman" ? "Man" : "Other";
}

export const findMatch = onCall(async (request) => {
  const db = admin.firestore();
  const rtdb = admin.database();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to find a match.");
  }

  const uid = request.auth.uid;

  const userDoc = await db.doc(`users/${uid}`).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found. Create a profile first.");
  }
  const userData = userDoc.data()!;
  const activeMatchId = userData.active_match_id as string | null;
  if (activeMatchId && activeMatchId.length > 0) {
    throw new HttpsError("failed-precondition", "You already have an active match. Finish it first.");
  }

  const gender = (userData.gender as string) ?? null;
  let preferredGender = (userData.preferred_gender as string) ?? null;
  if (!preferredGender || !PREFERENCES.includes(preferredGender as any)) {
    preferredGender = getDefaultPreferredGender(gender);
  }

  const elo = (userData.elo_rating as number) ?? 1000;
  const displayName = (userData.display_name as string) ?? "";

  const now = Date.now();
  const expireAt = now + QUEUE_TTL_MS;

  const queueEntry = {
    elo,
    display_name: displayName,
    timestamp: now,
    expire_at: expireAt,
    preferredGender,
  };

  await rtdb.ref(`matchmaking_queue/${uid}`).set(queueEntry);
  await rtdb.ref(`matchmaking_queue_index/${uid}`).set(preferredGender);

  return { success: true, preference: preferredGender };
});

export const joinQueue = findMatch;

/**
 * Removes the caller from the matchmaking queue (cancel).
 */
export const leaveQueue = onCall(async (request) => {
  const rtdb = admin.database();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;

  try {
    await rtdb.ref(`matchmaking_queue/${uid}`).remove();
    await rtdb.ref(`matchmaking_queue_index/${uid}`).remove();
    await rtdb.ref(`matchmaking_matches/${uid}`).remove();
  } catch (error) {
    console.error(`[leaveQueue] Error removing ${uid} from queue:`, error);
  }

  return { success: true };
});
