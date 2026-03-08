"use strict";
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
exports.checkMatchTimeouts = exports.seedTraits = exports.seedAiModels = exports.forfeitMatch = exports.onPresenceOffline = exports.onRTDBMessageSent = exports.onQueueWrite = exports.leaveQueue = exports.joinQueue = void 0;
/**
 * Load .env from functions directory (for emulator/local).
 * Production uses Firebase secrets via defineString; .env is ignored when absent.
 */
const path = __importStar(require("path"));
const dotenv_1 = require("dotenv");
(0, dotenv_1.config)({ path: path.resolve(__dirname, "../.env") });
(0, dotenv_1.config)({ path: path.resolve(__dirname, "../.env.local") });
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
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const characters_1 = require("./characters");
const finalizeMatch_1 = require("./finalizeMatch");
admin.initializeApp();
const db = admin.firestore();
const rtdb = admin.database();
// Re-export matchmaking callables and matcher trigger
var matchmaking_1 = require("./matchmaking");
Object.defineProperty(exports, "joinQueue", { enumerable: true, get: function () { return matchmaking_1.joinQueue; } });
Object.defineProperty(exports, "leaveQueue", { enumerable: true, get: function () { return matchmaking_1.leaveQueue; } });
var matchmakingMatcher_1 = require("./matchmakingMatcher");
Object.defineProperty(exports, "onQueueWrite", { enumerable: true, get: function () { return matchmakingMatcher_1.onQueueWrite; } });
// Re-export RTDB message trigger (replaces Firestore onUserMessageSent)
var onRTDBMessageSent_1 = require("./onRTDBMessageSent");
Object.defineProperty(exports, "onRTDBMessageSent", { enumerable: true, get: function () { return onRTDBMessageSent_1.onRTDBMessageSent; } });
// Re-export presence trigger: when user goes offline, forfeit their active match
var onPresenceOffline_1 = require("./onPresenceOffline");
Object.defineProperty(exports, "onPresenceOffline", { enumerable: true, get: function () { return onPresenceOffline_1.onPresenceOffline; } });
// ─────────────────────────────────────────────────────────────────────────────
// Forfeit: caller voluntarily ends match; opponent wins.
// ─────────────────────────────────────────────────────────────────────────────
exports.forfeitMatch = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in to forfeit.");
    }
    const matchId = request.data?.matchId;
    if (!matchId || typeof matchId !== "string") {
        throw new https_1.HttpsError("invalid-argument", "matchId is required.");
    }
    const callerUid = request.auth.uid;
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
        throw new https_1.HttpsError("not-found", "Match not found.");
    }
    const matchData = matchDoc.data();
    if (matchData.status !== "active") {
        throw new https_1.HttpsError("failed-precondition", "Match is no longer active.");
    }
    const playerIds = matchData.player_ids || [];
    if (!playerIds.includes(callerUid)) {
        throw new https_1.HttpsError("permission-denied", "You are not in this match.");
    }
    const opponentUid = playerIds.find((id) => id !== callerUid);
    if (!opponentUid) {
        throw new https_1.HttpsError("internal", "Could not determine opponent.");
    }
    await (0, finalizeMatch_1.finalizeMatch)({ matchId, winnerUid: opponentUid, playerIds });
    return { success: true };
});
// ─────────────────────────────────────────────────────────────────────────────
// One-time seed: seedAiModels callable. Invoke once to populate ai_models.
// Run from Flutter: FirebaseFunctions.instance.httpsCallable('seedAiModels').call()
// ─────────────────────────────────────────────────────────────────────────────
exports.seedAiModels = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in to seed.");
    }
    const batch = db.batch();
    for (const char of characters_1.AI_CHARACTERS) {
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
    return { success: true, count: characters_1.AI_CHARACTERS.length };
});
// ─────────────────────────────────────────────────────────────────────────────
// One-time seed: seedTraits callable. Populates traits/{category} with values.
// ─────────────────────────────────────────────────────────────────────────────
exports.seedTraits = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in to seed.");
    }
    const { TRAIT_DATA } = await Promise.resolve().then(() => __importStar(require("./traitData")));
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
exports.checkMatchTimeouts = (0, scheduler_1.onSchedule)("every 1 minutes", async () => {
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
        const playerIds = data.player_ids || [];
        if (playerIds.length < 2) {
            console.warn(`[timeout] Match ${matchId} has fewer than 2 players, skipping`);
            continue;
        }
        try {
            const stateSnap = await rtdb.ref(`active_states/${matchId}`).get();
            const state = stateSnap.val();
            const p1Vibe = state?.p1_vibe ?? 0;
            const p2Vibe = state?.p2_vibe ?? 0;
            if (p1Vibe > p2Vibe) {
                console.log(`[timeout] ${matchId}: P1 wins by meter (${p1Vibe} vs ${p2Vibe})`);
                await (0, finalizeMatch_1.finalizeMatch)({ matchId, winnerUid: playerIds[0], playerIds });
                await matchDoc.ref.update({ status: "timed_out" });
                await rtdb.ref(`active_states/${matchId}`).update({ status: "timed_out" });
            }
            else if (p2Vibe > p1Vibe) {
                console.log(`[timeout] ${matchId}: P2 wins by meter (${p2Vibe} vs ${p1Vibe})`);
                await (0, finalizeMatch_1.finalizeMatch)({ matchId, winnerUid: playerIds[1], playerIds });
                await matchDoc.ref.update({ status: "timed_out" });
                await rtdb.ref(`active_states/${matchId}`).update({ status: "timed_out" });
            }
            else {
                console.log(`[timeout] ${matchId}: Draw (both at ${p1Vibe})`);
                await (0, finalizeMatch_1.drawMatch)(matchId, playerIds);
            }
        }
        catch (err) {
            console.error(`[timeout] Error processing match ${matchId}:`, err);
        }
    }
});
//# sourceMappingURL=index.js.map