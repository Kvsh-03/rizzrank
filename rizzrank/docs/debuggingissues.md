# Role and Objective
You are an Expert Flutter and Firebase Architect. I need you to refactor a mobile game called "RizzRank". 

Currently, the app's codebase is built around a shared 1v1 group chat, but we are pivoting to a new architecture called the "Date Race". In this new architecture, two players compete to charm the same AI, but they do so in **completely private, sharded chat rooms** to prevent screen-peeking. 

The backend will use Cloudflare Workers AI (Llama 3.1 70B) for the AI's responses and Gemini 3.1 Flash-Lite to calculate a real-time "Heart Meter/Vibe Score" for each player. 

# The Problems to Fix
The current Flutter codebase has several critical disconnects and bugs that prevent this new architecture from working:
1. **The Shared Chat Disconnect:** The app currently reads/writes to `matches/{matchId}/chat/{messageId}`. It needs to read/write to `matches/{matchId}/players/{userId}/messages/{messageId}`.
2. **The "Invisible AI" Bug:** The `messagesStreamProvider` filters by `target_uid`, but `ChatMessage` doesn't parse or write this field, meaning AI responses get filtered out. By moving to private shards, we can remove this complicated query entirely.
3. **RTDB Typing Overwrite Bug:** The Realtime Database currently uses a single string for `is_typing`. If Player 1 types, it overwrites Player 2. This needs to be changed to a Map (`is_typing/{uid}: true`).
4. **Security Rules:** The `firestore.rules` and `database.rules.json` are locked to the old architecture and will throw `permission-denied` errors.

# Your Instructions
Please rewrite the following files to implement the "Date Race" architecture and fix the bugs. Provide the complete, updated code for each file.

### 1. Security Rules
**`firestore.rules`**
- Remove the old `/matches/{matchId}/chat/{messageId}` rule.
- Add a new rule for `/matches/{matchId}/players/{playerId}/messages/{messageId}`.
- A player can only `read` and `create` messages if `request.auth.uid == playerId`.
- Ensure `sender_uid` matches the user's uid when they create a user message.

**`database.rules.json`**
- Change the `is_typing` rule inside `active_states` to accept a map of UIDs: `"is_typing": { "$uid": { ".write": "auth != null && auth.uid === $uid", ".validate": "newData.isBoolean()" } }`.

### 2. Core Models & Services
**`lib/core/models/match_model.dart`**
- Change `isTyping` from a `String?` to a `Map<String, bool>`. 
- Parse it correctly in `fromMap`.

**`lib/core/services/database_service.dart`**
- Update `setTypingIndicator(String matchId, String uid, bool isTyping)` to write to the new RTDB path: `active_states/$matchId/is_typing/$uid`.

**`lib/core/providers/match_providers.dart`**
- Update `messagesStreamProvider`. 
- Change the Firestore path to: `matches/${params.matchId}/players/${params.uid}/messages`.
- Remove the `Filter.or('target_uid'...)` logic entirely, as the subcollection is now inherently private to the user. Just order by `timestamp`.

### 3. Presentation / UI Layer
**`lib/features/chat/presentation/battle_page.dart`**
- Update the `_onTextChanged` debounce logic to call the new `setTypingIndicator(matchId, user.uid, true/false)`.
- Update `_sendMessage` to write the new message to the private Firestore path: `matches/${widget.matchId}/players/${uid}/messages`.
- Update the UI to handle the new `isTyping` Map from `ActiveMatchState`. Check if the opponent's UID is in the map and set to `true` to display the "Opponent is typing..." text.

### 4. Cloud Functions Blueprint (Node.js)
Finally, write a brief comment block/blueprint at the end of your response showing what the Node.js Firebase Cloud Function `onDocumentCreated` trigger should look like to:
1. Listen to `matches/{matchId}/players/{playerId}/messages/{messageId}`.
2. Call Cloudflare Workers AI for the chat response.
3. Call Gemini 3.1 Flash-Lite to evaluate the chat history and update `active_states/{matchId}/p{1|2}_vibe` in RTDB.

Please provide the fully refactored files.