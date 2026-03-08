"use strict";
/**
 * RTDB onValueCreated trigger: when a user joins the queue, try to match pairs.
 * Uses a lock for single-worker semantics. FIFO, ELO ±150 (widen after 10s).
 * Gender preference: same preference matches. "Any" matches with Man, Woman, or Other.
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
exports.onQueueWrite = void 0;
const admin = __importStar(require("firebase-admin"));
const database_1 = require("firebase-functions/v2/database");
const firestore_1 = require("firebase-admin/firestore");
const database_2 = require("firebase-admin/database");
const traitData_1 = require("./traitData");
const db = admin.firestore();
const rtdb = admin.database();
const ELO_RANGE = 150;
const ELO_WIDEN_AFTER_MS = 10 * 1000; // 10 seconds
const MATCH_DURATION_MS = 10 * 60 * 1000; // 10 minutes
const PREFERENCES = ["Man", "Woman", "Other", "Any"];
async function acquireLock(instanceId) {
    const result = await rtdb.ref("matchmaking_lock/processor").transaction((current) => {
        if (current === null || current === undefined) {
            return instanceId;
        }
        return; // abort, don't change
    });
    return result.committed && result.snapshot.val() === instanceId;
}
async function releaseLock() {
    await rtdb.ref("matchmaking_lock/processor").set(null);
}
function getAiCharacterGender(pref1, pref2) {
    if (pref1 !== "Any" && pref2 !== "Any")
        return pref1; // same preference
    return pref1 === "Any" ? pref2 : pref1;
}
async function tryMatchPair(uid1, uid2, entry1, entry2, pref1, pref2) {
    const now = Date.now();
    const oldestTimestamp = Math.min(entry1.timestamp, entry2.timestamp);
    const waitTime = now - oldestTimestamp;
    const useStrictElo = waitTime < ELO_WIDEN_AFTER_MS;
    if (useStrictElo) {
        const eloDiff = Math.abs(entry1.elo - entry2.elo);
        if (eloDiff > ELO_RANGE)
            return false;
    }
    // else: after 10s, we accept any ELO (pick smallest diff - we already have a pair)
    const aiGender = getAiCharacterGender(pref1, pref2);
    const aiTraits = (0, traitData_1.pickDynamicTraits)(aiGender);
    const aiName = (0, traitData_1.generateCharacterName)();
    const aiSystemPrompt = (0, traitData_1.buildDynamicSystemPrompt)(aiTraits, aiName);
    const openingLine = (0, traitData_1.getDynamicOpeningLine)();
    const matchRef = db.collection("matches").doc();
    const matchId = matchRef.id;
    const playerIds = [uid1, uid2];
    const expiresAtMs = now + MATCH_DURATION_MS;
    const [user1Doc, user2Doc] = await Promise.all([
        db.doc(`users/${uid1}`).get(),
        db.doc(`users/${uid2}`).get(),
    ]);
    const elo1 = user1Doc.data()?.elo_rating ?? 1000;
    const elo2 = user2Doc.data()?.elo_rating ?? 1000;
    await db.runTransaction(async (tx) => {
        tx.set(matchRef, {
            player_ids: playerIds,
            winner_id: null,
            status: "active",
            target_phrase: "",
            ai_character_id: `dynamic_${aiName.toLowerCase()}`,
            ai_character_name: aiName,
            ai_system_prompt: aiSystemPrompt,
            ai_traits: aiTraits,
            elo_change: {},
            player_elo_before: { [uid1]: elo1, [uid2]: elo2 },
            is_game_over: false,
            expires_at: firestore_1.Timestamp.fromMillis(expiresAtMs),
            created_at: firestore_1.FieldValue.serverTimestamp(),
        });
        tx.update(db.doc(`users/${uid1}`), { active_match_id: matchId });
        tx.update(db.doc(`users/${uid2}`), { active_match_id: matchId });
    });
    await rtdb.ref(`active_states/${matchId}`).set({
        status: "active",
        player_ids: playerIds,
        ai_character_id: `dynamic_${aiName.toLowerCase()}`,
        ai_character_name: aiName,
        target_phrase: "",
        p1_vibe: 0,
        p2_vibe: 0,
        is_typing: null,
        winner_uid: null,
        expires_at: expiresAtMs,
        created_at: database_2.ServerValue.TIMESTAMP,
    });
    await rtdb.ref(`matchmaking_matches/${uid1}`).set({ matchId });
    await rtdb.ref(`matchmaking_matches/${uid2}`).set({ matchId });
    for (const playerId of playerIds) {
        await rtdb.ref(`matches/${matchId}/players/${playerId}/messages`).push({
            role: "model",
            content: openingLine,
            sender_uid: `ai_dynamic`,
            timestamp: database_2.ServerValue.TIMESTAMP,
            rizz_delta: null,
        });
    }
    await rtdb.ref(`matchmaking_queue/${pref1}/${uid1}`).remove();
    await rtdb.ref(`matchmaking_queue/${pref2}/${uid2}`).remove();
    await rtdb.ref(`matchmaking_queue_index/${uid1}`).remove();
    await rtdb.ref(`matchmaking_queue_index/${uid2}`).remove();
    return true;
}
async function processQueue(instanceId) {
    const lockAcquired = await acquireLock(instanceId);
    if (!lockAcquired) {
        await new Promise((r) => setTimeout(r, 1500));
        return processQueue(`matcher-retry-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    }
    try {
        const now = Date.now();
        for (const pref of PREFERENCES) {
            const queueRef = rtdb.ref(`matchmaking_queue/${pref}`);
            const snap = await queueRef.orderByChild("timestamp").limitToFirst(10).once("value");
            if (!snap.exists() || !snap.val())
                continue;
            const entries = [];
            snap.forEach((child) => {
                const data = child.val();
                if (data && data.expire_at > now) {
                    entries.push({ uid: child.key, data: { ...data, uid: child.key } });
                }
            });
            if (entries.length < 2)
                continue;
            const e1 = entries[0];
            const e2 = entries[1];
            const e1StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e1.uid}`).get()).exists();
            const e2StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e2.uid}`).get()).exists();
            if (!e1StillExists || !e2StillExists)
                continue;
            const matched = await tryMatchPair(e1.uid, e2.uid, e1.data, e2.data, pref, pref);
            if (matched)
                return;
        }
        for (const pref of ["Man", "Woman", "Other"]) {
            const anyRef = rtdb.ref("matchmaking_queue/Any");
            const prefRef = rtdb.ref(`matchmaking_queue/${pref}`);
            const [anySnap, prefSnap] = await Promise.all([
                anyRef.orderByChild("timestamp").limitToFirst(5).once("value"),
                prefRef.orderByChild("timestamp").limitToFirst(5).once("value"),
            ]);
            const anyEntries = [];
            const prefEntries = [];
            if (anySnap.exists() && anySnap.val()) {
                anySnap.forEach((child) => {
                    const data = child.val();
                    if (data && data.expire_at > now) {
                        anyEntries.push({ uid: child.key, data: { ...data, uid: child.key } });
                    }
                });
            }
            if (prefSnap.exists() && prefSnap.val()) {
                prefSnap.forEach((child) => {
                    const data = child.val();
                    if (data && data.expire_at > now) {
                        prefEntries.push({ uid: child.key, data: { ...data, uid: child.key } });
                    }
                });
            }
            if (anyEntries.length === 0 || prefEntries.length === 0)
                continue;
            const e1 = anyEntries[0];
            const e2 = prefEntries[0];
            const e1StillExists = (await rtdb.ref(`matchmaking_queue/Any/${e1.uid}`).get()).exists();
            const e2StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e2.uid}`).get()).exists();
            if (!e1StillExists || !e2StillExists)
                continue;
            const matched = await tryMatchPair(e1.uid, e2.uid, e1.data, e2.data, "Any", pref);
            if (matched)
                return;
        }
    }
    finally {
        await releaseLock();
    }
}
exports.onQueueWrite = (0, database_1.onValueCreated)("/matchmaking_queue/{preference}/{uid}", async (event) => {
    const instanceId = `matcher-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    await processQueue(instanceId);
});
//# sourceMappingURL=matchmakingMatcher.js.map