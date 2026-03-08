"use strict";
/**
 * Finalizes a match: computes ELO changes, updates Firestore match/users,
 * and marks RTDB active_states as completed.
 *
 * Called internally from onUserMessageSent when win condition is detected,
 * or from checkMatchTimeouts when a match expires.
 * Uses standard ELO K-factor formula for fair rating changes.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.finalizeMatch = finalizeMatch;
exports.drawMatch = drawMatch;
const admin = __importStar(require("firebase-admin"));
const K_FACTOR = 32;
function expectedScore(ratingA, ratingB) {
    return 1.0 / (1.0 + Math.pow(10, (ratingB - ratingA) / 400));
}
function computeEloDelta(winnerElo, loserElo) {
    const expected = expectedScore(winnerElo, loserElo);
    const winnerDelta = Math.round(K_FACTOR * (1 - expected));
    const loserDelta = -Math.round(K_FACTOR * expected);
    return { winnerDelta, loserDelta };
}
/**
 * Computes match duration in seconds from created_at to now.
 */
async function getMatchDuration(matchId) {
    const db = admin.firestore();
    const doc = await db.doc(`matches/${matchId}`).get();
    const createdAt = doc.data()?.created_at;
    if (createdAt && createdAt.toMillis) {
        return Math.round((Date.now() - createdAt.toMillis()) / 1000);
    }
    return 0;
}
async function finalizeMatch(params) {
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
    const winnerElo = winnerDoc.data()?.elo_rating ?? 1000;
    const loserElo = loserDoc.data()?.elo_rating ?? 1000;
    const { winnerDelta, loserDelta } = computeEloDelta(winnerElo, loserElo);
    const eloChange = {
        [winnerUid]: winnerDelta,
        [loserUid]: loserDelta,
    };
    const duration = await getMatchDuration(matchId);
    console.log(`[finalizeMatch] ${matchId}: winner=${winnerUid} (+${winnerDelta}), ` +
        `loser=${loserUid} (${loserDelta}), duration=${duration}s`);
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
async function drawMatch(matchId, playerIds) {
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
//# sourceMappingURL=finalizeMatch.js.map