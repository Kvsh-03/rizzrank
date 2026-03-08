# Role and Objective
You are an Expert Flutter and Firebase Architect. I am building "RizzRank", a dating-race game where players compete in private chat shards to charm an AI. 

Currently, the AI backend is crashing, meaning the AI never replies to the user. Additionally, the typing indicators feel like a group chat rather than an AI interaction. 

Please rewrite the following 3 files to fix the Gemini API crashes, implement the backend-driven AI typing state, and clean up the frontend UI.

### 1. Rewrite `functions/src/geminiChatService.ts`
The current `model.startChat({ history })` method crashes because the Gemini SDK strictly requires history to start with a `"user"` message and perfectly alternate. 
- **The Fix:** Delete `startChat`. Instead, format the `history` array into a single transcript string (e.g., `User: hi\nLuna: hello\nUser: how are you?`). 
- Append this transcript to the `systemContent`.
- Call `model.generateContent(systemContent)` to generate the response. This makes the AI completely immune to double-texting and history order crashes.

### 2. Rewrite `functions/src/index.ts`
- **Fix the Secret Key Crash:** Replace `geminiKey.value()` with `process.env.GEMINI_API_KEY || "mock"` when calling `getAIResponse` and `scoreMessage`. This prevents the function from crashing in local emulators if the secret isn't bound.
- **Implement AI Typing State:** Inside `onUserMessageSent`, wrap the AI logic in a `try/finally` block.
- At the start of the function, set the RTDB typing state: `await rtdb.ref(\`active_states/${matchId}/is_typing/ai_${playerId}\`).set(true);`
- In the `finally` block, ensure you delete it: `await rtdb.ref(\`active_states/${matchId}/is_typing/ai_${playerId}\`).remove();`

### 3. Rewrite `lib/features/chat/presentation/battle_page.dart`
- **Hide Human Typing:** Remove the `opponentIsTyping` variable and the "Opponent is typing..." UI block entirely.
- **Show AI Typing:** Create a new boolean `final aiIsTyping = liveMatch.isTyping['ai_${user.uid}'] == true;`.
- If `aiIsTyping` is true, render the `_TypingIndicator(avatarUrl: aiChar.avatarUrl, name: aiChar.name)` at the bottom of the ListView (index 0 when reversed).
- Remove the `_isLoading` lock on the Send button. Let the user double-text! When `_sendMessage` is called, immediately `_textController.clear()` and let them keep typing.

Please provide the completely rewritten, copy-pasteable code for these 3 files.