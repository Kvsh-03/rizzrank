"use strict";
/**
 * Gemini Chat Service - uses gemini-2.0-flash for AI dialogue.
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
const CHAT_MODEL = "gemini-2.0-flash";
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
/**
 * Calls Gemini 2.0 Flash with conversation history.
 * Injects win instruction if vibe > WIN_THRESHOLD.
 * Returns the AI reply text and whether a date-ask was detected.
 */
async function getAIResponse(apiKey, characterId, history, currentVibe) {
    const character = (0, characters_1.getCharacter)(characterId);
    let systemContent = character.systemInstruction;
    if (currentVibe > exports.WIN_THRESHOLD) {
        systemContent += WIN_INSTRUCTION;
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
        model: CHAT_MODEL,
        systemInstruction: systemContent,
        generationConfig: {
            temperature: 0.9,
            maxOutputTokens: 300,
        },
    });
    const geminiHistory = history.slice(0, -1).map((m) => ({
        role: m.role === "user" ? "user" : "model",
        parts: [{ text: m.text }],
    }));
    const lastMessage = history.length > 0
        ? history[history.length - 1].text
        : "";
    const chat = model.startChat({ history: geminiHistory });
    const result = await chat.sendMessage(lastMessage);
    const text = result.response.text().trim() ||
        "[AI could not generate a response]";
    const isDateAsk = currentVibe > exports.WIN_THRESHOLD && detectDateAsk(text);
    return { text, isDateAsk };
}
function detectDateAsk(text) {
    const lower = text.toLowerCase();
    return DATE_PHRASES.some((phrase) => lower.includes(phrase));
}
//# sourceMappingURL=geminiChatService.js.map