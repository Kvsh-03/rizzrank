"use strict";
/**
 * One-time seed script for the traits Firestore collection.
 * Run via: npx ts-node src/seedTraits.ts
 *
 * Populates traits/{category} with an array of possible values per category.
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
const admin = __importStar(require("firebase-admin"));
const traitData_1 = require("./traitData");
const PROJECT_ID = process.env.GCLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT_ID ||
    "rizzrank-f52cd";
if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();
async function seedTraits() {
    const batch = db.batch();
    const categories = Object.keys(traitData_1.TRAIT_DATA);
    for (const category of categories) {
        const ref = db.collection("traits").doc(category);
        batch.set(ref, { values: traitData_1.TRAIT_DATA[category] });
    }
    await batch.commit();
    console.log(`Seeded ${categories.length} trait categories to Firestore.`);
}
seedTraits().catch(console.error);
//# sourceMappingURL=seedTraits.js.map