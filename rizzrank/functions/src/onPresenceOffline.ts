/**
 * RTDB onValueUpdated trigger: when presence/{uid} is updated and is_online becomes false,
 * finalize any active match so the opponent wins (disconnect = forfeit).
 */

import * as admin from "firebase-admin";
import { onValueUpdated } from "firebase-functions/v2/database";
import { finalizeMatch } from "./finalizeMatch";

const db = admin.firestore();

const GRACE_PERIOD_MS = 30_000; // 30 seconds

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

    // Wait grace period to tolerate brief disconnects (iOS background, network blips)
    await new Promise((resolve) => setTimeout(resolve, GRACE_PERIOD_MS));

    // Re-check presence — user may have reconnected
    const presenceSnap = await admin.database().ref(`presence/${uid}`).get();
    const presenceVal = presenceSnap.val();
    if (presenceVal?.is_online === true) {
      console.log(`[onPresenceOffline] ${uid} reconnected within grace period, skipping forfeit`);
      return;
    }

    // Re-check match status — may have already completed
    const matchDoc = await db.doc(`matches/${activeMatchId}`).get();
    if (!matchDoc.exists) return;

    const matchData = matchDoc.data()!;
    if (matchData.status !== "active") return;

    const playerIds: string[] = matchData.player_ids || [];
    const opponentUid = playerIds.find((id) => id !== uid);
    if (!opponentUid) return;

    console.log(`[onPresenceOffline] ${uid} offline for ${GRACE_PERIOD_MS / 1000}s in match ${activeMatchId}, opponent ${opponentUid} wins`);
    await finalizeMatch({ matchId: activeMatchId, winnerUid: opponentUid, playerIds });
  }
);
