# RizzRank

🏁 RizzRank: The AI Dating Duel

RizzRank is a high-stakes, competitive social engineering game where two players race to charm an AI agent. Built with Flutter and Firebase, the game pits your "rizz" against a rival in a real-time battle of wits, persuasion, and romantic strategy.
💘 The Pitch

Two rivals, one stubborn AI. Each round features a unique agent with randomized personality traits. Your goal? Be the first to charm the bot into agreeing to a date. Climb the global ELO leaderboard and prove you’re the ultimate smooth-talker—or die trying (metaphorically).
🛠️ Architecture & Tech Stack
The Hybrid Database Strategy

To ensure the game is both cost-effective and lightning-fast, we utilize a dual-database architecture:

    Firestore (Source of Truth): Handles permanent data including User Profiles, ELO ratings, Match History, and AI Model definitions.

    Realtime Database (Live Signaling): Manages "in-motion" match data like the "Vibe Meter" (progress bars) and player connection status to ensure sub-100ms latency.

Database Schema
Collection/Path	Type	Description
/users	Firestore	Stores ELO, Rizz Titles, and player stats.
/matches	Firestore	Permanent archive of completed duels and chat logs.
/matchmaking	Firestore	Active queue using TTL (Time-To-Live) for auto-cleanup.
/active_states	RTDB	Real-time "Vibe" scores and typing indicators.
🛡️ Key Features
📈 ELO-Based Matchmaking

Utilizes a custom Firestore transaction-based queue. Players are matched with opponents of similar skill levels. As you win, your ELO increases, moving you from "Awkward Stranger" to "Casanova."
🧠 Randomized AI Personalities

No two matches are the same. AI agents are initialized with randomized traits (e.g., Sarcastic, Workaholic, Hopeless Romantic). There are no fixed difficulty levels—only the raw challenge of reading the room.
🔒 Anti-Cheat Security

All critical logic (ELO updates, win verification, and secret phrase detection) is handled via Firebase Cloud Functions. Firestore Security Rules prevent players from manually editing their scores or snooping on their opponent's chat.

## Firebase Setup & Development

From the project root (`rizzrank/`):

```bash
# 1. Generate firebase_options.dart (run once, or after adding new platforms)
dart pub global run flutterfire_cli:flutterfire configure --platforms=android,ios,macos

# 2. Build Cloud Functions
cd functions && npm install && npm run build

# 3. Start emulators (local dev)
cd .. && firebase emulators:start

# 4. Run Flutter app with emulators (in a separate terminal)
flutter run --dart-define=USE_EMULATORS=true

# 5. Deploy to production (when ready)
firebase deploy
```

**Prerequisites:** Firebase CLI (`firebase`), FlutterFire CLI (`dart pub global activate flutterfire_cli`). If `flutterfire` isn't found, add `export PATH="$PATH:$HOME/.pub-cache/bin"` to your shell config, or use `dart pub global run flutterfire_cli:flutterfire` instead. Ensure `.firebaserc` has your Firebase project ID.

**Cloud Functions secrets** (required for deploy): Set `OPENROUTER_API_KEY` and `GEMINI_API_KEY` via `firebase functions:secrets:set`.

### Google Sign-In on macOS

The app builds and runs on macOS without code signing. However, **Google Sign-In will fail with a keychain-error** until signing is enabled. To fix:

1. Open `macos/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities**.
3. Enable **Automatically manage signing** and select your **Team** (add your Apple ID in Xcode → Preferences → Accounts if needed).
4. Add the Keychain Sharing capability (or add `keychain-access-groups` to `macos/Runner/DebugProfile.entitlements` matching the format in `Release.entitlements`).
5. Rebuild with `flutter run -d macos`.

### Troubleshooting: firebase-admin v12 Modular Imports

Cloud Functions uses firebase-admin v12, which requires **modular imports** for RTDB:

```typescript
// ✅ Correct (modular)
import { ServerValue } from "firebase-admin/database";
created_at: ServerValue.TIMESTAMP

// ❌ Broken (compat namespace — ServerValue is undefined)
created_at: admin.database.ServerValue.TIMESTAMP
```

Firestore compat-style (`admin.firestore.FieldValue`) still works, but RTDB does not — always use `import { ServerValue } from "firebase-admin/database"`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
