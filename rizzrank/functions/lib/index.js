"use strict";
/**
 * RizzRank Date Race - Cloud Functions
 *
 * Trigger: onUserMessageSent - fires on Firestore writes to matches/{matchId}/chat
 * Pipeline:
 *   1. OpenRouter (Llama 3.1 70B) generates AI reply
 *   2. Gemini Flash-Lite judges the user message (0-15 rizz score)
 *   3. RTDB active_states/{matchId}/p1_vibe or p2_vibe is updated
 *   4. If vibe > 100: win instruction injected, date-ask detection triggers match end
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
exports.onUserMessageSent = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const params_1 = require("firebase-functions/params");
const openRouterService_1 = require("./openRouterService");
const geminiJudge_1 = require("./geminiJudge");
admin.initializeApp();
const db = admin.firestore();
const rtdb = admin.database();
const openrouterKey = (0, params_1.defineString)("OPENROUTER_API_KEY");
const geminiKey = (0, params_1.defineString)("GEMINI_API_KEY");
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
    const senderUid = data.sender_uid;
    const userText = data.text;
    if (!senderUid || !userText) {
        console.warn(`Missing sender_uid or text on ${matchId}/chat/${messageId}`);
        return;
    }
    // ── Read match metadata ──────────────────────────────────────────────
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
        console.error(`Match ${matchId} not found`);
        return;
    }
    const matchData = matchDoc.data();
    const characterId = matchData.ai_character_id || "luna";
    const playerIds = matchData.player_ids || [];
    // Determine if sender is p1 or p2 (by position in player_ids array)
    const playerIndex = playerIds.indexOf(senderUid);
    if (playerIndex === -1) {
        console.error(`Sender ${senderUid} not in match ${matchId} players`);
        return;
    }
    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";
    // ── Read current vibe from RTDB ──────────────────────────────────────
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe = vibeSnap.val() ?? 0;
    // ── Build chat history from Firestore (this player's messages only) ──
    const chatSnap = await db
        .collection(`matches/${matchId}/chat`)
        .where("sender_uid", "==", senderUid)
        .orderBy("timestamp", "asc")
        .get();
    // Also get AI replies to this player
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
            text: dd.text || "",
            _ts: dd.timestamp?.toMillis?.() ?? 0,
        };
    })
        .sort((a, b) => a._ts - b._ts);
    const history = allDocs.map((d) => ({
        role: d.role,
        text: d.text,
    }));
    // Find the last AI message for judge context
    const lastAIMsg = [...allDocs].reverse().find((d) => d.role === "model")?.text ?? "";
    // ── Run OpenRouter + Gemini Judge in parallel ────────────────────────
    const [aiResult, rizzDelta] = await Promise.all([
        (0, openRouterService_1.getAIResponse)(openrouterKey.value(), characterId, history, currentVibe),
        (0, geminiJudge_1.scoreMessage)(geminiKey.value(), characterId, lastAIMsg, userText),
    ]);
    // ── Write AI reply to Firestore chat subcollection ───────────────────
    await db.collection(`matches/${matchId}/chat`).add({
        role: "model",
        text: aiResult.text,
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
        // Update Firestore match document
        await db.doc(`matches/${matchId}`).update({
            status: "completed",
            winner_id: senderUid,
        });
        // Update RTDB active state
        await rtdb.ref(`active_states/${matchId}`).update({
            status: "completed",
            winner_uid: senderUid,
        });
        // Update player ELO in Firestore
        const winnerRef = db.doc(`users/${senderUid}`);
        await winnerRef.update({
            elo_rating: admin.firestore.FieldValue.increment(25),
            wins: admin.firestore.FieldValue.increment(1),
            total_games: admin.firestore.FieldValue.increment(1),
        });
        // Update loser ELO
        const loserUid = playerIds.find((id) => id !== senderUid);
        if (loserUid) {
            const loserRef = db.doc(`users/${loserUid}`);
            await loserRef.update({
                elo_rating: admin.firestore.FieldValue.increment(-12),
                losses: admin.firestore.FieldValue.increment(1),
                total_games: admin.firestore.FieldValue.increment(1),
            });
        }
    }
});
//# sourceMappingURL=index.js.map