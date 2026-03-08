/**
 * RTDB onValueUpdated trigger: when presence/{uid} is updated and is_online becomes false,
 * finalize any active match so the opponent wins (disconnect = forfeit).
 */

import * as admin from "firebase-admin";
import { onValueUpdated } from "firebase-functions/v2/database";
import { finalizeMatch } from "./finalizeMatch";

const db = admin.firestore();

export const onPresenceOffline = onValueUpdated(
  "presence/{uid}",
  async (event) => {
    const after = event.data.after.val();
    if (after?.is_online !== false) return;

    const uid = event.params.uid;
    const userDoc = await db.doc(`users/${uid}`).get();
    if (!userDoc.exists) return;

    const activeMatchId = (userDoc.data()?.active_match_id as string) || "";
    if (!activeMatchId) return;

    const matchDoc = await db.doc(`matches/${activeMatchId}`).get();
    if (!matchDoc.exists) return;

    const matchData = matchDoc.data()!;
    if (matchData.status !== "active") return;

    const playerIds: string[] = matchData.player_ids || [];
    const opponentUid = playerIds.find((id) => id !== uid);
    if (!opponentUid) return;

    console.log(`[onPresenceOffline] ${uid} went offline in match ${activeMatchId}, opponent ${opponentUid} wins`);
    await finalizeMatch({ matchId: activeMatchId, winnerUid: opponentUid, playerIds });
  }
);
