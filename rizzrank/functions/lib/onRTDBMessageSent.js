"use strict";
/**
 * RTDB trigger: when a user sends a message (matches/{matchId}/players/{playerId}/messages/{messageId}).
 * Runs the AI pipeline: load match, get AI response, judge, update vibe, check win.
 * Replaces Firestore onUserMessageSent for active matches.
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
exports.onRTDBMessageSent = void 0;
const admin = __importStar(require("firebase-admin"));
const database_1 = require("firebase-admin/database");
const database_2 = require("firebase-functions/v2/database");
const geminiChatService_1 = require("./geminiChatService");
const geminiJudge_1 = require("./geminiJudge");
const finalizeMatch_1 = require("./finalizeMatch");
const db = admin.firestore();
const rtdb = admin.database();
function resolveApiKey() {
    try {
        const { defineString } = require("firebase-functions/params");
        const geminiKey = defineString("GEMINI_API_KEY");
        const val = geminiKey.value();
        if (val && val !== "")
            return val;
    }
    catch {
        // defineString not available in emulator
    }
    return process.env.GEMINI_API_KEY || "mock";
}
exports.onRTDBMessageSent = (0, database_2.onValueCreated)("/matches/{matchId}/players/{playerId}/messages/{messageId}", async (event) => {
    const data = event.data.val();
    if (!data || data.role !== "user")
        return;
    const matchId = event.params.matchId;
    const playerId = event.params.playerId;
    const userText = data.content || data.text || "";
    if (!userText)
        return;
    const matchDoc = await db.doc(`matches/${matchId}`).get();
    if (!matchDoc.exists) {
        console.error(`Match ${matchId} not found`);
        return;
    }
    const matchData = matchDoc.data();
    if (matchData.status !== "active")
        return;
    const characterId = matchData.ai_character_id || "luna";
    const playerIds = matchData.player_ids || [];
    const aiTraits = matchData.ai_traits ?? {};
    const systemPromptOverride = matchData.ai_system_prompt;
    const characterNameOverride = matchData.ai_character_name;
    const playerIndex = playerIds.indexOf(playerId);
    if (playerIndex === -1)
        return;
    const vibeKey = playerIndex === 0 ? "p1_vibe" : "p2_vibe";
    const vibeRef = rtdb.ref(`active_states/${matchId}/${vibeKey}`);
    const vibeSnap = await vibeRef.get();
    const currentVibe = vibeSnap.val() ?? 0;
    const messagesRef = rtdb.ref(`matches/${matchId}/players/${playerId}/messages`);
    const messagesSnap = await messagesRef.orderByChild("timestamp").get();
    const allMsgs = [];
    if (messagesSnap.exists() && messagesSnap.val()) {
        const val = messagesSnap.val();
        for (const [k, v] of Object.entries(val)) {
            const ts = v.timestamp ?? 0;
            allMsgs.push({
                role: v.role || "user",
                text: v.content || v.text || "",
                _ts: ts,
            });
        }
    }
    allMsgs.sort((a, b) => a._ts - b._ts);
    const history = allMsgs.map((d) => ({
        role: d.role,
        text: d.text,
    }));
    const lastAIMsg = [...allMsgs].reverse().find((d) => d.role === "model")?.text ?? "";
    const lastAITimestamp = [...allMsgs].reverse().find((d) => d.role === "model")?._ts ?? 0;
    const userMsgTimestamp = data.timestamp ?? Date.now();
    const responseTimeSec = lastAITimestamp > 0
        ? (userMsgTimestamp - lastAITimestamp) / 1000
        : 4.0;
    const typingRef = rtdb.ref(`active_states/${matchId}/is_typing/ai_${playerId}`);
    await typingRef.set(true);
    const apiKey = resolveApiKey();
    try {
        let aiResult;
        let scoringResult;
        let turnResult;
        let aiError = false;
        try {
            aiResult = await (0, geminiChatService_1.getAIResponse)(apiKey, characterId, history, currentVibe, aiTraits, systemPromptOverride, characterNameOverride);
            scoringResult = await (0, geminiJudge_1.scoreMessage)(apiKey, characterId, lastAIMsg, userText, aiTraits);
        }
        catch (error) {
            console.error(`[${matchId}] Gemini API Error:`, error);
            aiError = true;
            aiResult = {
                text: "[System: AI is currently unavailable.]",
                isDateAsk: false,
            };
            scoringResult = {
                baseGood: 5,
                baseBad: 0,
                personaMult: 1.0,
                reasoning: "Fallback due to AI error.",
            };
        }
        const timingMult = (0, geminiJudge_1.getTimingMult)(responseTimeSec);
        turnResult = (0, geminiJudge_1.computeTurnScore)(scoringResult, timingMult);
        await rtdb.ref(`matches/${matchId}/players/${playerId}/messages`).push({
            role: "model",
            content: aiResult.text,
            sender_uid: `ai_${characterId}`,
            timestamp: database_1.ServerValue.TIMESTAMP,
            rizz_delta: aiError ? 0 : null,
        });
        let updatedVibe = currentVibe;
        if (!aiError) {
            const newVibe = await vibeRef.transaction((current) => {
                return (current ?? 0) + turnResult.turnScore;
            });
            updatedVibe = newVibe.snapshot.val() ?? currentVibe + turnResult.turnScore;
        }
        const messageRef = event.data.ref;
        await messageRef.update({
            rizz_delta: aiError ? 0 : turnResult.turnScore,
            scoring: {
                base_good: turnResult.baseGood,
                base_bad: turnResult.baseBad,
                persona_mult: turnResult.personaMult,
                timing_mult: turnResult.timingMult,
                reasoning: turnResult.reasoning,
            },
        });
        console.log(`[${matchId}] ${playerId} (${vibeKey}): +${aiError ? 0 : turnResult.turnScore} rizz → ${updatedVibe}` +
            (aiResult.isDateAsk ? " ★ DATE ASK" : ""));
        if (!aiError && aiResult.isDateAsk && updatedVibe > geminiChatService_1.WIN_THRESHOLD) {
            console.log(`[${matchId}] WINNER: ${playerId}`);
            await (0, finalizeMatch_1.finalizeMatch)({ matchId, winnerUid: playerId, playerIds });
        }
    }
    finally {
        await typingRef.remove();
    }
});
//# sourceMappingURL=onRTDBMessageSent.js.map