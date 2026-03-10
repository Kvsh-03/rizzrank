"use strict";
/**
 * RTDB-based matchmaking: joinQueue, leaveQueue, and findMatch.
 *
 * Global queue structure: matchmaking_queue/{uid}
 * Index for preference lookup: matchmaking_queue_index/{uid}
 *
 * Matching is triggered by onQueueWrite in matchmakingMatcher.ts.
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
exports.leaveQueue = exports.joinQueue = exports.findMatch = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const QUEUE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const PREFERENCES = ["Man", "Woman", "Other", "Any"];
function getDefaultPreferredGender(gender) {
    if (!gender)
        return "Woman"; // fallback
    return gender === "Man" ? "Woman" : gender === "Woman" ? "Man" : "Other";
}
exports.findMatch = (0, https_1.onCall)(async (request) => {
    const db = admin.firestore();
    const rtdb = admin.database();
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in to find a match.");
    }
    const uid = request.auth.uid;
    const userDoc = await db.doc(`users/${uid}`).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("not-found", "User profile not found. Create a profile first.");
    }
    const userData = userDoc.data();
    const activeMatchId = userData.active_match_id;
    if (activeMatchId && activeMatchId.length > 0) {
        throw new https_1.HttpsError("failed-precondition", "You already have an active match. Finish it first.");
    }
    const gender = userData.gender ?? null;
    let preferredGender = userData.preferred_gender ?? null;
    if (!preferredGender || !PREFERENCES.includes(preferredGender)) {
        preferredGender = getDefaultPreferredGender(gender);
    }
    const elo = userData.elo_rating ?? 1000;
    const displayName = userData.display_name ?? "";
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
exports.joinQueue = exports.findMatch;
/**
 * Removes the caller from the matchmaking queue (cancel).
 */
exports.leaveQueue = (0, https_1.onCall)(async (request) => {
    const rtdb = admin.database();
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    try {
        await rtdb.ref(`matchmaking_queue/${uid}`).remove();
        await rtdb.ref(`matchmaking_queue_index/${uid}`).remove();
        await rtdb.ref(`matchmaking_matches/${uid}`).remove();
    }
    catch (error) {
        console.error(`[leaveQueue] Error removing ${uid} from queue:`, error);
    }
    return { success: true };
});
//# sourceMappingURL=matchmaking.js.map