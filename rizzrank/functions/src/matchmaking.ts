/**
 * Server-side matchmaking via HTTPS callable.
 *
 * Flow:
 *   1. Authenticated user calls findMatch.
 *   2. Function queries matchmaking queue for opponents within +/-150 ELO.
 *   3. If opponent found: Firestore transaction deletes both, creates match doc,
 *      creates RTDB active_states/{matchId} initial state.
 *   4. If no opponent: adds caller to queue with expire_at TTL.
 *   5. Returns { matched: boolean, matchId?: string }.
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { pickRandomTraits } from "./traitData";
import { getOpeningLine } from "./characters";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { ServerValue } from "firebase-admin/database";


const ELO_RANGE = 150;
const QUEUE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MATCH_DURATION_MS = 10 * 60 * 1000; // 10 minutes

const AI_CHARACTERS = ["luna", "atlas", "zephyr"];

function pickRandomCharacter(): string {
  return AI_CHARACTERS[Math.floor(Math.random() * AI_CHARACTERS.length)];
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
  const myElo = (userData.elo_rating as number) ?? 1000;
  const myDisplayName = (userData.display_name as string) ?? "";

  const minElo = myElo - ELO_RANGE;
  const maxElo = myElo + ELO_RANGE;

  const result = await db.runTransaction(async (transaction) => {
    // Query queue ordered by timestamp (FIFO), limited batch for perf
    const queueSnap = await transaction.get(
      db.collection("matchmaking").orderBy("timestamp", "asc").limit(50)
    );

    // Find first compatible opponent (not self, within ELO range)
    let opponentDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    for (const doc of queueSnap.docs) {
      if (doc.id === uid) continue;
      const data = doc.data();
      const opponentElo = (data.elo_rating as number) ?? 1000;
      if (opponentElo >= minElo && opponentElo <= maxElo) {
        opponentDoc = doc;
        break;
      }
    }

    if (!opponentDoc) {
      // FIX 1: Restore the Queue Logic instead of instant solo matching.
      // Put the user into the matchmaking queue so the next person can find them.
      const expireAt = Date.now() + QUEUE_TTL_MS;
      transaction.set(db.collection("matchmaking").doc(uid), {
        uid: uid,
        display_name: myDisplayName,
        elo_rating: myElo,
        timestamp: FieldValue.serverTimestamp(),
        expire_at: expireAt,
      });

      return { matched: false as const };
    }

    const opponentUid = opponentDoc.id;
    const opponentData = opponentDoc.data();
    const opponentElo = (opponentData.elo_rating as number) ?? 1000;

    // Create match document
    const matchRef = db.collection("matches").doc();
    const matchId = matchRef.id;
    const playerIds = [uid, opponentUid];
    const aiCharacterId = pickRandomCharacter();
    const expiresAtMs = Date.now() + MATCH_DURATION_MS;

    transaction.set(matchRef, {
      player_ids: playerIds,
      winner_id: null,
      status: "active",
      target_phrase: "",
      ai_character_id: aiCharacterId,
      ai_traits: pickRandomTraits(),
      elo_change: {},
      player_elo_before: { [uid]: myElo, [opponentUid]: opponentElo },
      is_game_over: false,
      expires_at: Timestamp.fromMillis(expiresAtMs),
      created_at: FieldValue.serverTimestamp(),
    });

    // Set active_match_id on both players
    transaction.update(db.doc(`users/${uid}`), { active_match_id: matchId });
    transaction.update(db.doc(`users/${opponentUid}`), { active_match_id: matchId });

    // Remove both from queue
    transaction.delete(db.collection("matchmaking").doc(uid));
    transaction.delete(db.collection("matchmaking").doc(opponentUid));

    return {
      matched: true as const,
      matchId,
      playerIds,
      aiCharacterId,
      expiresAtMs,
      opponentDisplayName: (opponentData.display_name as string) ?? "",
    };
  });

  // If matched, create RTDB active_states (outside transaction -- RTDB is not transactional with Firestore)
  if (result.matched) {
    await rtdb.ref(`active_states/${result.matchId}`).set({
      status: "active",
      player_ids: result.playerIds,
      ai_character_id: result.aiCharacterId,
      target_phrase: "",
      p1_vibe: 0,
      p2_vibe: 0,
      is_typing: null,
      winner_uid: null,
      expires_at: result.expiresAtMs,
      created_at: ServerValue.TIMESTAMP,
    });

    // FIX 2: Write initial AI greeting to the NEW private player shards
    const openingLine = getOpeningLine(result.aiCharacterId);

    for (const playerId of result.playerIds) {
      await db.collection(`matches/${result.matchId}/players/${playerId}/messages`).add({
        role: "model",
        content: openingLine,
        sender_uid: `ai_${result.aiCharacterId}`,
        timestamp: FieldValue.serverTimestamp(),
        rizz_delta: null,
      });
    }

    return { matched: true, matchId: result.matchId };
  }

  return { matched: false };
});

/**
 * Removes the caller from the matchmaking queue (cancel).
 */
export const leaveQueue = onCall(async (request) => {
  const db = admin.firestore();
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  await db.collection("matchmaking").doc(request.auth.uid).delete();
  return { success: true };
});
