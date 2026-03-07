"use strict";
/**
 * OpenRouter Chat Service - calls Llama 3.1 70B for AI dialogue.
 *
 * If the player's vibe score exceeds WIN_THRESHOLD, a hidden instruction
 * is injected to make the AI ask the user on a date.
 * After receiving the response, date-ask detection runs to finalize the match.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.WIN_THRESHOLD = void 0;
exports.getAIResponse = getAIResponse;
const characters_1 = require("./characters");
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MODEL = "meta-llama/llama-3.1-70b-instruct";
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
 * Calls OpenRouter Llama 3.1 70B with conversation history.
 * Injects win instruction if vibe > WIN_THRESHOLD.
 * Returns the AI reply text and whether a date-ask was detected.
 */
async function getAIResponse(apiKey, characterId, history, currentVibe) {
    const character = (0, characters_1.getCharacter)(characterId);
    let systemContent = character.systemInstruction;
    if (currentVibe > exports.WIN_THRESHOLD) {
        systemContent += WIN_INSTRUCTION;
    }
    const messages = [
        { role: "system", content: systemContent },
        ...history.map((m) => ({
            role: m.role === "model" ? "assistant" : m.role,
            content: m.text,
        })),
    ];
    const res = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "HTTP-Referer": "https://rizzrank.app",
            "X-Title": "RizzRank Date Race",
        },
        body: JSON.stringify({
            model: MODEL,
            messages,
            temperature: 0.9,
            max_tokens: 300,
        }),
    });
    if (!res.ok) {
        const errBody = await res.text();
        throw new Error(`OpenRouter ${res.status}: ${errBody}`);
    }
    const data = (await res.json());
    const text = data.choices?.[0]?.message?.content?.trim() ||
        "[AI could not generate a response]";
    const isDateAsk = currentVibe > exports.WIN_THRESHOLD && detectDateAsk(text);
    return { text, isDateAsk };
}
function detectDateAsk(text) {
    const lower = text.toLowerCase();
    return DATE_PHRASES.some((phrase) => lower.includes(phrase));
}
//# sourceMappingURL=openRouterService.js.map