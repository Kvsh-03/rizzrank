"use strict";
/**
 * RTDB onValueUpdated trigger: when presence/{uid} is updated and is_online becomes false,
 * finalize any active match so the opponent wins (disconnect = forfeit).
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
exports.onPresenceOffline = void 0;
const admin = __importStar(require("firebase-admin"));
const database_1 = require("firebase-functions/v2/database");
const finalizeMatch_1 = require("./finalizeMatch");
const db = admin.firestore();
exports.onPresenceOffline = (0, database_1.onValueUpdated)("presence/{uid}", async (event) => {
    const after = event.data.after.val();
    if (after?.is_online !== false)
        return;
    const uid = event.params.uid;
    const userDoc = await db.doc(`users/${uid}`).get();
    if (!userDoc.exists)
        return;
    const activeMatchId = userDoc.data()?.active_match_id || "";
    if (!activeMatchId)
        return;
    const matchDoc = await db.doc(`matches/${activeMatchId}`).get();
    if (!matchDoc.exists)
        return;
    const matchData = matchDoc.data();
    if (matchData.status !== "active")
        return;
    const playerIds = matchData.player_ids || [];
    const opponentUid = playerIds.find((id) => id !== uid);
    if (!opponentUid)
        return;
    console.log(`[onPresenceOffline] ${uid} went offline in match ${activeMatchId}, opponent ${opponentUid} wins`);
    await (0, finalizeMatch_1.finalizeMatch)({ matchId: activeMatchId, winnerUid: opponentUid, playerIds });
});
//# sourceMappingURL=onPresenceOffline.js.map