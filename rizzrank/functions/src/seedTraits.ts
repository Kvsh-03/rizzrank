/**
 * One-time seed script for the traits Firestore collection.
 * Run via: npx ts-node src/seedTraits.ts
 *
 * Populates traits/{category} with an array of possible values per category.
 */

import * as admin from "firebase-admin";
import { TRAIT_DATA } from "./traitData";

const PROJECT_ID =
  process.env.GCLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT_ID ||
  "rizzrank-f52cd";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

async function seedTraits(): Promise<void> {
  const batch = db.batch();
  const categories = Object.keys(TRAIT_DATA);

  for (const category of categories) {
    const ref = db.collection("traits").doc(category);
    batch.set(ref, { values: TRAIT_DATA[category] });
  }

  await batch.commit();
  console.log(`Seeded ${categories.length} trait categories to Firestore.`);
}

seedTraits().catch(console.error);
