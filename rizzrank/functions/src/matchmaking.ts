/**
 * RTDB-based matchmaking: joinQueue and leaveQueue.
 *
 * joinQueue: Adds user to RTDB matchmaking_queue/{preference}/{uid}.
 *   - Rejects if active_match_id is set.
 *   - Default preferred_gender = opposite of gender (Man->Woman, Woman->Man, Other->Other).
 *
 * leaveQueue: Removes user from queue. Uses matchmaking_queue_index/{uid} to find preference.
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

export const joinQueue = onCall(async (request) => {
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
  };

  await rtdb.ref(`matchmaking_queue/${preferredGender}/${uid}`).set(queueEntry);
  await rtdb.ref(`matchmaking_queue_index/${uid}`).set(preferredGender);

  return { success: true, preference: preferredGender };
});

/**
 * Removes the caller from the matchmaking queue (cancel).
 */
export const leaveQueue = onCall(async (request) => {
  const rtdb = admin.database();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;

  const indexSnap = await rtdb.ref(`matchmaking_queue_index/${uid}`).get();
  const preference = indexSnap.val() as string | null;

  if (preference) {
    await rtdb.ref(`matchmaking_queue/${preference}/${uid}`).remove();
    await rtdb.ref(`matchmaking_queue_index/${uid}`).remove();
  }

  return { success: true };
});
