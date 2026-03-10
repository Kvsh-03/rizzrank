/**
 * RTDB-based matchmaking: Global queue with mutual consent & priority scoring.
 * 
 * Algorithm:
 * 1. Single global queue (matchmaking_queue/{uid}) with preferredGender field
 * 2. Triggered on any queue write (join or leave)
 * 3. Each trigger: find all valid pairs, match top-scoring pair, exit
 * 4. Queue write from match removal triggers next trigger (self-driving loop)
 * 
 * Pair validation:
 * - Preference filter: (A.pref == "Any" OR B.pref == "Any" OR A.pref == B.pref)
 * - Mutual consent: |eloA - eloB| <= radiusA AND |eloA - eloB| <= radiusB
 * - Radius: 150 + (150 × ⌊T/3⌋) where T is wait time in seconds
 * 
 * Priority scoring:
 * - Score = (waitTimeA + waitTimeB) - |eloA - eloB|
 * - Higher score = older players + closer ELO
 */

import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";
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

const ELO_BASE_RANGE = 150;
const MATCH_DURATION_MS = 10 * 60 * 1000; // 10 minutes
export const PREFERENCES = ["Man", "Woman", "Other", "Any"] as const;

// DEBUG_MATCHMAKER: Set via firebase functions:config:set matchmaking.debug=true
const DEBUG_MATCHMAKER = process.env.DEBUG_MATCHMAKER === "true";

function debugLog(...args: any[]) {
  if (DEBUG_MATCHMAKER) {
    console.log("[DEBUG]", ...args);
  }
}

interface QueueEntry {
  uid: string;
  elo: number;
  display_name: string;
  timestamp: number;
  expire_at: number;
  preferredGender: string;
}

interface ValidPair {
  entry1: { uid: string; data: QueueEntry };
  entry2: { uid: string; data: QueueEntry };
  score: number;
}

interface LockOwner {
  owner: string;
  expires: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// Lock Mechanism with TTL
// ─────────────────────────────────────────────────────────────────────────────

async function acquireLock(instanceId: string): Promise<boolean> {
  const result = await rtdb.ref("matchmaking_lock/processor").transaction(
    (current: LockOwner | null) => {
      if (!current || current.expires < Date.now()) {
        // Lock expired or doesn't exist, take it
        return { owner: instanceId, expires: Date.now() + 5000 };
      }
      // Lock still valid, abort
      return;
    }
  );

  if (!result.committed) {
    return false;
  }

  const currentLock = result.snapshot.val() as LockOwner | null;
  return currentLock?.owner === instanceId;
}

async function releaseLock(): Promise<void> {
  await rtdb.ref("matchmaking_lock/processor").set(null);
}

// ─────────────────────────────────────────────────────────────────────────────
// Core Algorithm Helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Calculate dynamic ELO radius based on wait time.
 * Formula: 150 + (150 × ⌊T/3⌋) where T is wait time in seconds
 * 
 * 0-2.9s: ±150
 * 3-5.9s: ±300
 * 6-8.9s: ±450
 * 9-11.9s: ±600
 * etc.
 */
function getRadiusForWaitTime(waitTimeMs: number): number {
  const waitSeconds = Math.floor(waitTimeMs / 1000);
  const radiusLevels = Math.floor(waitSeconds / 3);
  return ELO_BASE_RANGE + (ELO_BASE_RANGE * radiusLevels);
}

/**
 * Check if two preferences are compatible.
 * Rule: (A.pref == "Any" OR B.pref == "Any" OR A.pref == B.pref)
 */
function isPreferenceCompatible(pref1: string, pref2: string): boolean {
  return pref1 === "Any" || pref2 === "Any" || pref1 === pref2;
}

/**
 * Validate if two players can match (mutual consent).
 * Both players' radii must include the other's ELO.
 */
function isValidPair(entry1: QueueEntry, entry2: QueueEntry, now: number): boolean {
  // Preference filter
  if (!isPreferenceCompatible(entry1.preferredGender, entry2.preferredGender)) {
    debugLog(`[isValidPair] Preference mismatch: ${entry1.preferredGender} vs ${entry2.preferredGender}`);
    return false;
  }

  // Calculate radii for both players
  const radius1 = getRadiusForWaitTime(now - entry1.timestamp);
  const radius2 = getRadiusForWaitTime(now - entry2.timestamp);
  const eloDiff = Math.abs(entry1.elo - entry2.elo);

  debugLog(`[isValidPair] ${entry1.uid} (ELO: ${entry1.elo}, radius: ${radius1}) vs ${entry2.uid} (ELO: ${entry2.elo}, radius: ${radius2}), diff: ${eloDiff}`);

  // Mutual consent: both must accept each other
  if (eloDiff > radius1) {
    debugLog(`[isValidPair] ${entry1.uid} rejects ${entry2.uid}: ELO diff ${eloDiff} > radius ${radius1}`);
    return false;
  }

  if (eloDiff > radius2) {
    debugLog(`[isValidPair] ${entry2.uid} rejects ${entry1.uid}: ELO diff ${eloDiff} > radius ${radius2}`);
    return false;
  }

  debugLog(`[isValidPair] ✓ Valid pair: ${entry1.uid} ↔ ${entry2.uid}`);
  return true;
}

/**
 * Calculate match priority score.
 * Formula: (waitTimeA + waitTimeB) - |eloA - eloB|
 * 
 * Higher score = older players + closer ELO
 */
function calculateMatchScore(entry1: QueueEntry, entry2: QueueEntry, now: number): number {
  const waitTime1 = now - entry1.timestamp;
  const waitTime2 = now - entry2.timestamp;
  const eloDiff = Math.abs(entry1.elo - entry2.elo);

  const score = (waitTime1 + waitTime2) - eloDiff;
  
  debugLog(`[calculateMatchScore] ${entry1.uid} (wait: ${waitTime1}ms) + ${entry2.uid} (wait: ${waitTime2}ms) - ELO diff ${eloDiff} = ${score}`);
  
  return score;
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue Operations
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetch all non-expired users from global queue.
 */
async function getAllUsersInQueue(now: number): Promise<{ uid: string; data: QueueEntry }[]> {
  const snap = await rtdb.ref("matchmaking_queue").once("value");
  
  if (!snap.exists() || !snap.val()) {
    return [];
  }

  const entries: { uid: string; data: QueueEntry }[] = [];
  
  snap.forEach((child) => {
    const data = child.val();
    if (data && data.expire_at > now) {
      entries.push({ uid: child.key!, data: { ...data, uid: child.key! } });
    }
  });

  debugLog(`[getAllUsersInQueue] Found ${entries.length} non-expired users`);
  
  return entries;
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Creation
// ─────────────────────────────────────────────────────────────────────────────

async function tryMatchPair(
  uid1: string,
  uid2: string,
  entry1: QueueEntry,
  entry2: QueueEntry
): Promise<boolean> {
  const now = Date.now();
  const eloDiff = Math.abs(entry1.elo - entry2.elo);

  debugLog(`[tryMatchPair] Attempting match: ${uid1} (ELO: ${entry1.elo}) vs ${uid2} (ELO: ${entry2.elo}), diff: ${eloDiff}`);

  // Determine AI character gender
  const aiGender = entry1.preferredGender === "Any" ? entry2.preferredGender : entry1.preferredGender;
  const aiTraits = pickDynamicTraits(aiGender);
  const aiName = generateCharacterName();
  
  console.log(`[tryMatchPair] Creating match with AI character: ${aiName} (${aiGender})`);
  
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

  // Send opening message to both players
  for (const playerId of playerIds) {
    await rtdb.ref(`matches/${matchId}/players/${playerId}/messages`).push({
      role: "model",
      content: openingLine,
      sender_uid: `ai_dynamic`,
      timestamp: ServerValue.TIMESTAMP,
      rizz_delta: null,
    });
  }

  // Remove both players from queue
  try {
    await rtdb.ref(`matchmaking_queue/${uid1}`).remove();
    await rtdb.ref(`matchmaking_queue/${uid2}`).remove();
    console.log(`[tryMatchPair] ✓ Match created: ${matchId}, removed ${uid1} and ${uid2} from queue`);
    return true;
  } catch (queueError) {
    console.error(`[tryMatchPair] Failed to remove players from queue:`, queueError);
    
    // Rollback match on failure
    try {
      await rtdb.ref(`active_states/${matchId}`).remove();
      await db.runTransaction(async (tx) => {
        tx.delete(matchRef);
        tx.update(db.doc(`users/${uid1}`), { active_match_id: null });
        tx.update(db.doc(`users/${uid2}`), { active_match_id: null });
      });
      console.log(`[tryMatchPair] Rolled back match ${matchId} due to queue removal failure`);
    } catch (rollbackError) {
      console.error(`[tryMatchPair] Rollback failed:`, rollbackError);
    }
    
    throw queueError;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Processing Loop
// ─────────────────────────────────────────────────────────────────────────────

async function processQueue(instanceId: string): Promise<void> {
  debugLog(`[processQueue] Starting instance: ${instanceId}`);

  const lockAcquired = await acquireLock(instanceId);
  if (!lockAcquired) {
    debugLog(`[processQueue] Lock not acquired, exiting`);
    return;
  }

  console.log(`[processQueue] Lock acquired, processing queue...`);

  try {
    const now = Date.now();
    
    // 1. Fetch all non-expired users
    const allUsers = await getAllUsersInQueue(now);
    
    debugLog(`[processQueue] Queue size: ${allUsers.length} users`);
    
    // High-water mark warning
    if (allUsers.length > 50) {
      console.warn(`[processQueue] HIGH WATER MARK: ${allUsers.length} users in queue`);
    }

    if (allUsers.length < 2) {
      debugLog(`[processQueue] Only ${allUsers.length} users, nothing to do`);
      return;
    }

    // 2. Find all valid pairs
    const validPairs: ValidPair[] = [];

    for (let i = 0; i < allUsers.length; i++) {
      for (let j = i + 1; j < allUsers.length; j++) {
        const entry1 = allUsers[i].data;
        const entry2 = allUsers[j].data;

        if (isValidPair(entry1, entry2, now)) {
          const score = calculateMatchScore(entry1, entry2, now);
          validPairs.push({
            entry1: allUsers[i],
            entry2: allUsers[j],
            score,
          });
        }
      }
    }

    debugLog(`[processQueue] Found ${validPairs.length} valid pairs`);

    if (validPairs.length === 0) {
      debugLog(`[processQueue] No valid pairs found, exiting`);
      return;
    }

    // 3. Sort by score descending (highest priority first)
    validPairs.sort((a, b) => b.score - a.score);

    // 4. Match top-scoring pair
    const topPair = validPairs[0];
    
    console.log(`[processQueue] MATCH FOUND: ${topPair.entry1.uid} (score: ${topPair.score}) vs ${topPair.entry2.uid}`);
    debugLog(`[processQueue] Top pair: ${topPair.entry1.uid} (ELO: ${topPair.entry1.data.elo}, wait: ${now - topPair.entry1.data.timestamp}ms) vs ${topPair.entry2.uid} (ELO: ${topPair.entry2.data.elo}, wait: ${now - topPair.entry2.data.timestamp}ms)`);

    try {
      await tryMatchPair(
        topPair.entry1.uid,
        topPair.entry2.uid,
        topPair.entry1.data,
        topPair.entry2.data
      );
    } catch (error) {
      console.error(`[processQueue] Error creating match:`, error);
    }

  } finally {
    await releaseLock();
    debugLog(`[processQueue] Lock released`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger: onValueWritten (not just onValueCreated)
// ─────────────────────────────────────────────────────────────────────────────

export const onQueueWrite = onValueWritten(
  "/matchmaking_queue/{uid}",
  async (event) => {
    const uid = event.params.uid;
    
    // Check if user was added or removed
    const data = event.data.after.val();

    if (!data) {
      console.log(`[onQueueWrite] User ${uid} removed from queue, triggering re-match`);
    } else {
      console.log(`[onQueueWrite] User ${uid} joined queue`);
    }

    const instanceId = `matcher-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    
    try {
      await processQueue(instanceId);
    } catch (error) {
      console.error(`[onQueueWrite] Error processing queue:`, error);
    }
  }
);
