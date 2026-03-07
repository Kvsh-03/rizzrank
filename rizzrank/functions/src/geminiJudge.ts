/**
 * Gemini Judge - evaluates rizz on a 0-15 scale using Gemini Flash-Lite.
 * Writes score delta to RTDB active_states/{matchId}/p1_vibe or p2_vibe.
 */

import { GoogleGenerativeAI } from "@google/generative-ai";
import { getCharacter } from "./characters";

const MODEL_NAME = "gemini-2.0-flash-lite";

function buildScoringPrompt(
  characterDescription: string,
  lastAIMessage: string,
  userMessage: string
): string {
  return `You are a dating coach AI judge. Score the following message on a "rizz scale" from 0 to 15.
- 0-3: Boring, generic, no charm.
- 4-7: Decent effort, some personality.
- 8-12: Smooth, witty, emotionally intelligent.
- 13-15: Exceptional. Masterclass in charm.

Only respond with a single integer. No explanation.

Character context: ${characterDescription}
AI's last message: "${lastAIMessage}"
User's message: "${userMessage}"

Score:`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/**
 * Scores a user message using Gemini Flash-Lite.
 * Returns the rizz delta (0-15).
 */
export async function scoreMessage(
  apiKey: string,
  characterId: string,
  lastAIMessage: string,
  userMessage: string
): Promise<number> {
  const character = getCharacter(characterId);
  const prompt = buildScoringPrompt(
    character.description,
    lastAIMessage,
    userMessage
  );

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: MODEL_NAME });

  const result = await model.generateContent(prompt);
  const responseText = result.response.text().trim();
  const score = parseInt(responseText, 10);

  if (isNaN(score)) {
    console.warn(`Gemini returned non-numeric score: "${responseText}", defaulting to 5`);
    return 5;
  }

  return clamp(score, 0, 15);
}
