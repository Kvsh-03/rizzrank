/**
 * One-time seed script for ai_models Firestore collection.
 * Run via: npx ts-node src/seedAiModels.ts
 * Or deploy as a callable and invoke once.
 *
 * Populates ai_models/{model_slug} with name, personality_summary, system_prompt.
 */

import * as admin from "firebase-admin";
import { AI_CHARACTERS } from "./characters";

if (!admin.apps.length) {
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "rizzrank-f52cd";
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

async function seed(): Promise<void> {
  const batch = db.batch();

  for (const char of AI_CHARACTERS) {
    const ref = db.collection("ai_models").doc(char.id);
    batch.set(ref, {
      name: char.name,
      personality_summary: char.description,
      system_prompt: char.systemInstruction,
      role: char.role,
      avatar_url: char.avatar,
      difficulty: char.difficulty,
    });
  }

  await batch.commit();
  console.log(`Seeded ${AI_CHARACTERS.length} AI models to Firestore.`);
}

seed().catch(console.error);
