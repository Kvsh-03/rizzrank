/**
 * Finalizes a match: computes ELO changes, updates Firestore match/users,
 * and marks RTDB active_states as completed.
 *
 * Called internally from onUserMessageSent when win condition is detected,
 * or from checkMatchTimeouts when a match expires.
 * Uses standard ELO K-factor formula for fair rating changes.
 */

import * as admin from "firebase-admin";

const K_FACTOR = 32;

function expectedScore(ratingA: number, ratingB: number): number {
  return 1.0 / (1.0 + Math.pow(10, (ratingB - ratingA) / 400));
}

function computeEloDelta(
  winnerElo: number,
  loserElo: number
): { winnerDelta: number; loserDelta: number } {
  const expected = expectedScore(winnerElo, loserElo);
  const winnerDelta = Math.round(K_FACTOR * (1 - expected));
  const loserDelta = -Math.round(K_FACTOR * expected);
  return { winnerDelta, loserDelta };
}

/**
 * Computes match duration in seconds from created_at to now.
 */
async function getMatchDuration(matchId: string): Promise<number> {
  const db = admin.firestore();
  const doc = await db.doc(`matches/${matchId}`).get();
  const createdAt = doc.data()?.created_at;
  if (createdAt && createdAt.toMillis) {
    return Math.round((Date.now() - createdAt.toMillis()) / 1000);
  }
  return 0;
}

export interface FinalizeParams {
  matchId: string;
  winnerUid: string;
  playerIds: string[];
}

export async function finalizeMatch(params: FinalizeParams): Promise<void> {
  const db = admin.firestore();
  const rtdb = admin.database();
  const { matchId, winnerUid, playerIds } = params;
  const loserUid = playerIds.find((id) => id !== winnerUid);
  if (!loserUid) {
    console.error(`[finalizeMatch] Could not determine loser for match ${matchId}`);
    return;
  }

  const [winnerDoc, loserDoc] = await Promise.all([
    db.doc(`users/${winnerUid}`).get(),
    db.doc(`users/${loserUid}`).get(),
  ]);

  const winnerElo = (winnerDoc.data()?.elo_rating as number) ?? 1000;
  const loserElo = (loserDoc.data()?.elo_rating as number) ?? 1000;

  const { winnerDelta, loserDelta } = computeEloDelta(winnerElo, loserElo);

  const eloChange: Record<string, number> = {
    [winnerUid]: winnerDelta,
    [loserUid]: loserDelta,
  };

  const duration = await getMatchDuration(matchId);

  console.log(
    `[finalizeMatch] ${matchId}: winner=${winnerUid} (+${winnerDelta}), ` +
    `loser=${loserUid} (${loserDelta}), duration=${duration}s`
  );

  const batch = db.batch();

  batch.update(db.doc(`matches/${matchId}`), {
    status: "completed",
    winner_id: winnerUid,
    elo_change: eloChange,
    is_game_over: true,
    duration,
  });

  batch.update(db.doc(`users/${winnerUid}`), {
    elo_rating: admin.firestore.FieldValue.increment(winnerDelta),
    wins: admin.firestore.FieldValue.increment(1),
    total_games: admin.firestore.FieldValue.increment(1),
    last_played: admin.firestore.FieldValue.serverTimestamp(),
    active_match_id: null,
  });

  batch.update(db.doc(`users/${loserUid}`), {
    elo_rating: admin.firestore.FieldValue.increment(loserDelta),
    losses: admin.firestore.FieldValue.increment(1),
    total_games: admin.firestore.FieldValue.increment(1),
    last_played: admin.firestore.FieldValue.serverTimestamp(),
    active_match_id: null,
  });

  await batch.commit();

  await rtdb.ref(`active_states/${matchId}`).update({
    status: "completed",
    winner_uid: winnerUid,
  });
}

/**
 * Handles a draw (timeout with equal vibes). No ELO changes, but match is
 * marked complete and active_match_id is cleared on both players.
 */
export async function drawMatch(matchId: string, playerIds: string[]): Promise<void> {
  const db = admin.firestore();
  const rtdb = admin.database();

  const duration = await getMatchDuration(matchId);

  console.log(`[drawMatch] ${matchId}: draw (equal vibes), duration=${duration}s`);

  const batch = db.batch();

  batch.update(db.doc(`matches/${matchId}`), {
    status: "timed_out",
    winner_id: null,
    is_game_over: true,
    duration,
  });

  for (const uid of playerIds) {
    batch.update(db.doc(`users/${uid}`), {
      total_games: admin.firestore.FieldValue.increment(1),
      last_played: admin.firestore.FieldValue.serverTimestamp(),
      active_match_id: null,
    });
  }

  await batch.commit();

  await rtdb.ref(`active_states/${matchId}`).update({
    status: "timed_out",
    winner_uid: null,
  });
}
