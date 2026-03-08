"use strict";
/**
 * RizzRank Date Race - Cloud Functions
 *
 * Exports:
 *   - onUserMessageSent: Firestore trigger on matches/{matchId}/chat/{messageId}
 *   - findMatch, leaveQueue: HTTPS callables for matchmaking
 *   - cleanupExpiredMatchmaking: Scheduled cleanup
 *   - checkMatchTimeouts: Scheduled match timeout enforcement (every 30s)
 *
 * Pipeline (onUserMessageSent):
 *   1. Read AI character from Firestore ai_models collection (fallback to hardcoded)
 *   2. OpenRouter (Llama 3.1 70B) generates AI reply
 *   3. Gemini Flash-Lite judges the user message (0-15 rizz score)
 *   4. RTDB active_states/{matchId}/p1_vibe or p2_vibe is updated
 *   5. If vibe > 100 and date-ask detected: finalizeMatch is called
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
exports.checkMatchTimeouts = exports.cleanupExpiredMatchmaking = exports.onUserMessageSent = exports.leaveQueue = exports.findMatch = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const params_1 = require("firebase-functions/params");
const openRouterService_1 = require("./openRouterService");
const geminiJudge_1 = require("./geminiJudge");
const characters_1 = require("./characters");
const finalizeMatch_1 = require("./finalizeMatch");
admin.initializeApp();
const db = admin.firestore();
const rtdb = admin.database();
const openrouterKey = (0, params_1.defineString)("OPENROUTER_API_KEY");
const geminiKey = (0, params_1.defineString)("GEMINI_API_KEY");
// Re-export matchmaking callables
var matchmaking_1 = require("./matchmaking");
Object.defineProperty(exports, "findMatch", { enumerable: true, get: function () { return matchmaking_1.findMatch; } });
Object.defineProperty(exports, "leaveQueue", { enumerable: true, get: function () { return matchmaking_1.leaveQueue; } });
async function loadCharacter(characterId) {
    const doc = await db.doc(`ai_models/${characterId}`).get();
    if (doc.exists) {
        const data = doc.data();
        return {
            systemInstruction: data.system_prompt ?? "",
            description: data.personality_summary ?? "",
        };
    }
    // Fallback to hardcoded characters.ts
    const fallback = (0, characters_1.getCharacter)(characterId);
    return {
        systemInstruction: fallback.systemInstruction,
        description: fallback.description,
    };
}
// ─────────────────────────────────────────────────────────────────────────────
// Firestore trigger: matches/{matchId}/chat/{messageId}
// Fires when any new message is added to the chat subcollection.
// Only processes messages where role === "user".
// ─────────────────────────────────────────────────────────────────────────────
exports.onUserMessageSent = (0, firestore_1.onDocumentCreated)("matches/{matchId}/chat/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const data = snap.data();
    if (!data || data.role !== "user")
        return;
    const matchId = event.params.matchId;
    const messageId = event.params.messageId;
    const senderUid = data.sender_uid || "";
    // Support both "content" (new) and "text" (legacy) field names
    const userText = data.content || data.text || "";
    if (!senderUid || !userText) {
        console.warn(`Missing sender_uid or content on ${matchId}/chat/${messageId}`);
        return;
    }
    // ── Read match metadata ──────────────────────────────────────────────
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
        console.error(`Match ${matchId} not found`);
        return;
    }
    const matchData = matchDoc.data();
    if (matchData.status !== "active") {
        console.warn(`Match ${matchId} status is '${matchData.status}', ignoring message`);
        return;
    }
    const characterId = matchData.ai_character_id || "luna";
    const playerIds = matchData.player_ids || [];
    // Determine if sender is p1 or p2 (by position in player_ids array)
    const playerIndex = playerIds.indexOf(senderUid);
    if (playerIndex === -1) {
        console.error(`Sender ${senderUid} not in match ${matchId} players`);
        return;
    }
    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";
    // ── Load AI character config ─────────────────────────────────────────
    const character = await loadCharacter(characterId);
    // ── Read current vibe from RTDB ──────────────────────────────────────
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe = vibeSnap.val() ?? 0;
    // ── Build chat history from Firestore (this player's conversation) ───
    const chatSnap = await db
        .collection(`matches/${matchId}/chat`)
        .where("sender_uid", "==", senderUid)
        .orderBy("timestamp", "asc")
        .get();
    const aiRepliesSnap = await db
        .collection(`matches/${matchId}/chat`)
        .where("target_uid", "==", senderUid)
        .where("role", "==", "model")
        .orderBy("timestamp", "asc")
        .get();
    const allDocs = [...chatSnap.docs, ...aiRepliesSnap.docs]
        .map((d) => {
        const dd = d.data();
        return {
            role: dd.role || "user",
            text: dd.content || dd.text || "",
            _ts: dd.timestamp?.toMillis?.() ?? 0,
        };
    })
        .sort((a, b) => a._ts - b._ts);
    const history = allDocs.map((d) => ({
        role: d.role,
        text: d.text,
    }));
    const lastAIMsg = [...allDocs].reverse().find((d) => d.role === "model")?.text ?? "";
    // ── Run OpenRouter + Gemini Judge in parallel ────────────────────────
    const [aiResult, rizzDelta] = await Promise.all([
        (0, openRouterService_1.getAIResponse)(openrouterKey.value(), characterId, history, currentVibe),
        (0, geminiJudge_1.scoreMessage)(geminiKey.value(), characterId, lastAIMsg, userText),
    ]);
    // ── Write AI reply to Firestore chat subcollection ───────────────────
    await db.collection(`matches/${matchId}/chat`).add({
        role: "model",
        content: aiResult.text,
        sender_uid: `ai_${characterId}`,
        target_uid: senderUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        rizz_delta: null,
    });
    // ── Update vibe in RTDB via transaction (atomic increment) ───────────
    const newVibe = await vibeRef.transaction((current) => {
        return (current ?? 0) + rizzDelta;
    });
    const updatedVibe = newVibe.snapshot.val() ?? currentVibe + rizzDelta;
    // ── Write rizz_delta back onto the original user message ─────────────
    await snap.ref.update({ rizz_delta: rizzDelta });
    console.log(`[${matchId}] ${senderUid} (${vibeKey}): +${rizzDelta} rizz → ${updatedVibe} total` +
        (aiResult.isDateAsk ? " ★ DATE ASK DETECTED" : ""));
    // ── Win detection: if AI asked for a date, finalize the match ────────
    if (aiResult.isDateAsk && updatedVibe > openRouterService_1.WIN_THRESHOLD) {
        console.log(`[${matchId}] WINNER: ${senderUid}`);
        await (0, finalizeMatch_1.finalizeMatch)({ matchId, winnerUid: senderUid, playerIds });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Scheduled: cleanup expired matchmaking entries every 5 minutes
// ─────────────────────────────────────────────────────────────────────────────
exports.cleanupExpiredMatchmaking = (0, scheduler_1.onSchedule)("every 5 minutes", async () => {
    const now = Date.now();
    const expired = await db
        .collection("matchmaking")
        .where("expire_at", "<", now)
        .get();
    if (expired.empty) {
        console.log("[cleanup] No expired matchmaking entries");
        return;
    }
    const batch = db.batch();
    for (const doc of expired.docs) {
        batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`[cleanup] Removed ${expired.size} expired matchmaking entries`);
});
// ─────────────────────────────────────────────────────────────────────────────
// Scheduled: enforce match timeouts every 30 seconds.
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