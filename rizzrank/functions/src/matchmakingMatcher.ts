/**
 * RTDB onValueCreated trigger: when a user joins the queue, try to match pairs.
 * Uses a lock for single-worker semantics. FIFO, ELO ±150 (widen after 10s).
 * Gender preference: same preference matches. "Any" matches with Man, Woman, or Other.
 */

import * as admin from "firebase-admin";
import { onValueCreated } from "firebase-functions/v2/database";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { ServerValue } from "firebase-admin/database";
import {
  pickDynamicTraits,
  generateCharacterName,
  buildDynamicSystemPrompt,
  getDynamicOpeningLine,
} from "./traitData";

const db = admin.firestore();
const rtdb = admin.database();

const ELO_RANGE = 150;
const ELO_WIDEN_AFTER_MS = 10 * 1000; // 10 seconds
const MATCH_DURATION_MS = 10 * 60 * 1000; // 10 minutes
const PREFERENCES = ["Man", "Woman", "Other", "Any"] as const;

interface QueueEntry {
  uid: string;
  elo: number;
  display_name: string;
  timestamp: number;
  expire_at: number;
}

async function acquireLock(instanceId: string): Promise<boolean> {
  const result = await rtdb.ref("matchmaking_lock/processor").transaction((current) => {
    if (current === null || current === undefined) {
      return instanceId;
    }
    return; // abort, don't change
  });
  return result.committed && result.snapshot.val() === instanceId;
}

async function releaseLock(): Promise<void> {
  await rtdb.ref("matchmaking_lock/processor").set(null);
}

function getAiCharacterGender(pref1: string, pref2: string): string {
  if (pref1 !== "Any" && pref2 !== "Any") return pref1; // same preference
  return pref1 === "Any" ? pref2 : pref1;
}

async function tryMatchPair(
  uid1: string,
  uid2: string,
  entry1: QueueEntry,
  entry2: QueueEntry,
  pref1: string,
  pref2: string
): Promise<boolean> {
  const now = Date.now();
  const oldestTimestamp = Math.min(entry1.timestamp, entry2.timestamp);
  const waitTime = now - oldestTimestamp;
  const useStrictElo = waitTime < ELO_WIDEN_AFTER_MS;

  if (useStrictElo) {
    const eloDiff = Math.abs(entry1.elo - entry2.elo);
    if (eloDiff > ELO_RANGE) return false;
  }
  // else: after 10s, we accept any ELO (pick smallest diff - we already have a pair)

  const aiGender = getAiCharacterGender(pref1, pref2);
  const aiTraits = pickDynamicTraits(aiGender);
  const aiName = generateCharacterName();
  const aiSystemPrompt = buildDynamicSystemPrompt(aiTraits, aiName);
  const openingLine = getDynamicOpeningLine();

  const matchRef = db.collection("matches").doc();
  const matchId = matchRef.id;
  const playerIds = [uid1, uid2];
  const expiresAtMs = now + MATCH_DURATION_MS;

  const [user1Doc, user2Doc] = await Promise.all([
    db.doc(`users/${uid1}`).get(),
    db.doc(`users/${uid2}`).get(),
  ]);
  const elo1 = (user1Doc.data()?.elo_rating as number) ?? 1000;
  const elo2 = (user2Doc.data()?.elo_rating as number) ?? 1000;

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
      expires_at: Timestamp.fromMillis(expiresAtMs),
      created_at: FieldValue.serverTimestamp(),
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
    created_at: ServerValue.TIMESTAMP,
  });

  await rtdb.ref(`matchmaking_matches/${uid1}`).set({ matchId });
  await rtdb.ref(`matchmaking_matches/${uid2}`).set({ matchId });

  for (const playerId of playerIds) {
    await rtdb.ref(`matches/${matchId}/players/${playerId}/messages`).push({
      role: "model",
      content: openingLine,
      sender_uid: `ai_dynamic`,
      timestamp: ServerValue.TIMESTAMP,
      rizz_delta: null,
    });
  }

  await rtdb.ref(`matchmaking_queue/${pref1}/${uid1}`).remove();
  await rtdb.ref(`matchmaking_queue/${pref2}/${uid2}`).remove();
  await rtdb.ref(`matchmaking_queue_index/${uid1}`).remove();
  await rtdb.ref(`matchmaking_queue_index/${uid2}`).remove();

  return true;
}

async function processQueue(instanceId: string): Promise<void> {
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

      if (!snap.exists() || !snap.val()) continue;

      const entries: { uid: string; data: QueueEntry }[] = [];
      snap.forEach((child) => {
        const data = child.val();
        if (data && data.expire_at > now) {
          entries.push({ uid: child.key!, data: { ...data, uid: child.key! } });
        }
      });

      if (entries.length < 2) continue;

      const e1 = entries[0];
      const e2 = entries[1];

      const e1StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e1.uid}`).get()).exists();
      const e2StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e2.uid}`).get()).exists();

      if (!e1StillExists || !e2StillExists) continue;

      const matched = await tryMatchPair(
        e1.uid,
        e2.uid,
        e1.data,
        e2.data,
        pref,
        pref
      );
      if (matched) return;
    }

    for (const pref of ["Man", "Woman", "Other"]) {
      const anyRef = rtdb.ref("matchmaking_queue/Any");
      const prefRef = rtdb.ref(`matchmaking_queue/${pref}`);

      const [anySnap, prefSnap] = await Promise.all([
        anyRef.orderByChild("timestamp").limitToFirst(5).once("value"),
        prefRef.orderByChild("timestamp").limitToFirst(5).once("value"),
      ]);

      const anyEntries: { uid: string; data: QueueEntry }[] = [];
      const prefEntries: { uid: string; data: QueueEntry }[] = [];

      if (anySnap.exists() && anySnap.val()) {
        anySnap.forEach((child) => {
          const data = child.val();
          if (data && data.expire_at > now) {
            anyEntries.push({ uid: child.key!, data: { ...data, uid: child.key! } });
          }
        });
      }
      if (prefSnap.exists() && prefSnap.val()) {
        prefSnap.forEach((child) => {
          const data = child.val();
          if (data && data.expire_at > now) {
            prefEntries.push({ uid: child.key!, data: { ...data, uid: child.key! } });
          }
        });
      }

      if (anyEntries.length === 0 || prefEntries.length === 0) continue;

      const e1 = anyEntries[0];
      const e2 = prefEntries[0];

      const e1StillExists = (await rtdb.ref(`matchmaking_queue/Any/${e1.uid}`).get()).exists();
      const e2StillExists = (await rtdb.ref(`matchmaking_queue/${pref}/${e2.uid}`).get()).exists();

      if (!e1StillExists || !e2StillExists) continue;

      const matched = await tryMatchPair(
        e1.uid,
        e2.uid,
        e1.data,
        e2.data,
        "Any",
        pref
      );
      if (matched) return;
    }
  } finally {
    await releaseLock();
  }
}

export const onQueueWrite = onValueCreated(
  "/matchmaking_queue/{preference}/{uid}",
  async (event) => {
    const instanceId = `matcher-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    await processQueue(instanceId);
  }
);
