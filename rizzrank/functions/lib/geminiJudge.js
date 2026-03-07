"use strict";
/**
 * Gemini Judge - evaluates rizz on a 0-15 scale using Gemini Flash-Lite.
 * Writes score delta to RTDB active_states/{matchId}/p1_vibe or p2_vibe.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.scoreMessage = scoreMessage;
const generative_ai_1 = require("@google/generative-ai");
const characters_1 = require("./characters");
const MODEL_NAME = "gemini-2.0-flash-lite";
function buildScoringPrompt(characterDescription, lastAIMessage, userMessage) {
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
function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}
/**
 * Scores a user message using Gemini Flash-Lite.
 * Returns the rizz delta (0-15).
 */
async function scoreMessage(apiKey, characterId, lastAIMessage, userMessage) {
    const character = (0, characters_1.getCharacter)(characterId);
    const prompt = buildScoringPrompt(character.description, lastAIMessage, userMessage);
    const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
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
//# sourceMappingURL=geminiJudge.js.map