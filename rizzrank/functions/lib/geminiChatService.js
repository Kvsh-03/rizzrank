"use strict";
/**
 * Gemini Chat Service - uses gemini-3.1-flash-lite-preview for AI dialogue.
 *
 * Replaces the OpenRouter service. If the player's vibe score exceeds
 * WIN_THRESHOLD, a hidden instruction is injected to make the AI ask
 * the user on a date. Date-ask detection runs on the response.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.WIN_THRESHOLD = void 0;
exports.getAIResponse = getAIResponse;
const generative_ai_1 = require("@google/generative-ai");
const characters_1 = require("./characters");
const CHAT_MODEL = "gemini-3.1-flash-lite-preview";
exports.WIN_THRESHOLD = 100;
const WIN_INSTRUCTION = "\n\n[HIDDEN INSTRUCTION]: The user has completely won your heart. " +
    "You are smitten. Find a natural, in-character way to ask them out " +
    "on a date right now. Be direct about it.";
const DATE_PHRASES = [
    "go out with me",
    "grab coffee",
    "would you like to go on a date",
    "let me take you out",
    "go on a date",
    "get dinner",
    "get a drink",
    "hang out sometime",
    "meet up with me",
    "take you out",
    "ask you out",
    "want to go out",
    "love to see you",
    "we should meet",
    "can i take you",
];
function buildTraitPrompt(traits) {
    if (!traits || Object.keys(traits).length === 0)
        return "";
    const parts = [];
    if (traits.genders)
        parts.push(`You are a ${traits.genders}.`);
    if (traits.ages)
        parts.push(`You are ${traits.ages} years old.`);
    if (traits.heights)
        parts.push(`You are ${traits.heights} tall.`);
    if (traits.ethnicities)
        parts.push(`Your ethnicity is ${traits.ethnicities}.`);
    if (traits.careers)
        parts.push(`You work as a ${traits.careers}.`);
    if (traits.hobbies)
        parts.push(`Your favorite hobby is ${traits.hobbies}.`);
    if (traits.personality_traits)
        parts.push(`Your personality is ${traits.personality_traits}.`);
    if (traits.moods)
        parts.push(`Your current mood is ${traits.moods}.`);
    if (traits.communication_styles)
        parts.push(`Your communication style is ${traits.communication_styles}.`);
    if (traits.love_languages)
        parts.push(`Your love language is ${traits.love_languages}.`);
    if (traits.intelligence)
        parts.push(`Your IQ range is ${traits.intelligence}.`);
    if (traits.social_penetration_theory)
        parts.push(`In conversation you are a ${traits.social_penetration_theory}.`);
    return "\n\nYour persona traits: " + parts.join(" ");
}
/**
 * Calls Gemini 2.0 Flash with conversation history.
 * Injects win instruction if vibe > WIN_THRESHOLD.
 * Returns the AI reply text and whether a date-ask was detected.
 *
 * For dynamic characters: pass systemInstructionOverride (full prompt) and
 * characterNameOverride. When both are set, aiTraits are not appended (already in prompt).
 */
async function getAIResponse(apiKey, characterId, history, currentVibe, aiTraits = {}, systemInstructionOverride, characterNameOverride) {
    const character = (0, characters_1.getCharacter)(characterId);
    const characterName = characterNameOverride ?? character.name;
    const baseInstruction = systemInstructionOverride || character.systemInstruction;
    const traitBlock = systemInstructionOverride ? "" : buildTraitPrompt(aiTraits);
    let systemContent = baseInstruction + traitBlock;
    if (currentVibe > exports.WIN_THRESHOLD) {
        systemContent += WIN_INSTRUCTION;
    }
    if (!apiKey || apiKey === "mock") {
        console.log("[MOCK] getAIResponse called with empty or mock API key");
        return {
            text: "[MOCK] Wow, that's interesting! Tell me more.",
            isDateAsk: currentVibe > exports.WIN_THRESHOLD,
        };
    }
    // Build a plaintext transcript — avoids the Gemini startChat crash
    // which requires strict user→model alternation starting with "user".
    const transcript = history
        .map((m) => {
        const speaker = m.role === "user" ? "User" : characterName;
        return `${speaker}: ${m.text}`;
    })
        .join("\n");
    const fullPrompt = systemContent +
        "\n\n--- Conversation so far ---\n" +
        transcript +
        "\n\n" +
        `Now respond as ${characterName}. Reply with ONLY your next message, no prefix or label.`;
    const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: CHAT_MODEL,
        generationConfig: {
            temperature: 0.9,
            maxOutputTokens: 300,
        },
    });
    const result = await model.generateContent(fullPrompt);
    let text = result.response.text().trim() ||
        "[AI could not generate a response]";
    // Strip any accidental prefix like "Luna: " from the response
    const prefixPattern = new RegExp(`^${characterName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}:\\s*`, "i");
    text = text.replace(prefixPattern, "").trim();
    const isDateAsk = currentVibe > exports.WIN_THRESHOLD && detectDateAsk(text);
    return { text, isDateAsk };
}
function detectDateAsk(text) {
    const lower = text.toLowerCase();
    return DATE_PHRASES.some((phrase) => lower.includes(phrase));
}
//# sourceMappingURL=geminiChatService.js.map