"use strict";
/**
 * Gemini Judge - evaluates rizz using the Turn Score formula.
 *
 * Formula: Turn Score = [(Base Good x Persona Mult) x Timing Mult] - Base Bad
 *
 * Gemini returns structured JSON with base_good, base_bad, persona_mult, reasoning.
 * Timing mult is computed server-side from message timestamps.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTimingMult = getTimingMult;
exports.scoreMessage = scoreMessage;
exports.computeTurnScore = computeTurnScore;
const generative_ai_1 = require("@google/generative-ai");
const characters_1 = require("./characters");
const SCORING_MODEL = "gemini-2.0-flash-lite";
function buildScoringPrompt(characterDescription, characterName, lastAIMessage, userMessage) {
    return `You are a dating coach AI judge. Evaluate the user's message for "rizz" (charm/flirting skill).

You MUST respond with ONLY a valid JSON object. No markdown, no explanation, no code fences.

Character: ${characterName} - ${characterDescription}

The character's last message: "${lastAIMessage}"
The user's response: "${userMessage}"

Evaluate and return JSON with these fields:
- "base_good" (integer 0-15): Points for charm, wit, emotional intelligence, humor.
  0-3 = boring/generic. 4-7 = decent effort. 8-12 = smooth and witty. 13-15 = masterclass.
- "base_bad" (integer 0-10): Deductions for cringe, generic pickup lines, rudeness, insults, being boring.
  0 = nothing bad. 1-3 = minor cringe. 4-7 = actively bad. 8-10 = terrible.
- "persona_mult" (number: 0.5, 1.0, or 1.5):
  1.5 = the message specifically resonates with this character's personality/interests/love language, makes them feel "seen".
  1.0 = neutral, doesn't particularly play to or against the character's personality.
  0.5 = goes against the character's values/personality (e.g. being slow/boring with an impatient character).
- "reasoning" (string): One sentence explaining the score, referencing the character's personality.`;
}
function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}
/**
 * Computes the timing multiplier based on response time.
 * - <3s: 0.5x (too fast = needy)
 * - 3-5s: 1/(x-2) curve (sweet spot, peaks at 3s)
 * - >5s: 1.0x (neutral)
 */
function getTimingMult(responseTimeSeconds) {
    if (responseTimeSeconds < 3)
        return 0.5;
    if (responseTimeSeconds <= 5)
        return 1 / (responseTimeSeconds - 2);
    return 1.0;
}
/**
 * Asks Gemini to score a user message and returns the raw scoring components.
 */
async function scoreMessage(apiKey, characterId, lastAIMessage, userMessage) {
    const character = (0, characters_1.getCharacter)(characterId);
    const prompt = buildScoringPrompt(character.description, character.name, lastAIMessage, userMessage);
    const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: SCORING_MODEL });
    const result = await model.generateContent(prompt);
    const responseText = result.response.text().trim();
    try {
        const cleaned = responseText
            .replace(/```json\s*/gi, "")
            .replace(/```\s*/g, "")
            .trim();
        const parsed = JSON.parse(cleaned);
        return {
            baseGood: clamp(typeof parsed.base_good === "number" ? parsed.base_good : 5, 0, 15),
            baseBad: clamp(typeof parsed.base_bad === "number" ? parsed.base_bad : 0, 0, 10),
            personaMult: [0.5, 1.0, 1.5].includes(parsed.persona_mult) ? parsed.persona_mult : 1.0,
            reasoning: typeof parsed.reasoning === "string" ? parsed.reasoning : "No reasoning provided",
        };
    }
    catch (e) {
        console.warn(`Gemini returned unparseable scoring: "${responseText}", using defaults`);
        return {
            baseGood: 5,
            baseBad: 0,
            personaMult: 1.0,
            reasoning: "Scoring parse error, default applied",
        };
    }
}
/**
 * Computes the full Turn Score from scoring components and timing.
 * Formula: [(Base Good x Persona Mult) x Timing Mult] - Base Bad
 */
function computeTurnScore(scoring, timingMult) {
    const raw = ((scoring.baseGood * scoring.personaMult) * timingMult) - scoring.baseBad;
    const turnScore = Math.max(0, Math.round(raw));
    return {
        turnScore,
        baseGood: scoring.baseGood,
        baseBad: scoring.baseBad,
        personaMult: scoring.personaMult,
        timingMult: Math.round(timingMult * 100) / 100,
        reasoning: scoring.reasoning,
    };
}
//# sourceMappingURL=geminiJudge.js.map