# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is RizzRank?

A Flutter mobile app where players compete in real-time "rizz battles" — chatting with AI characters (powered by Gemini) to fill a vibe meter. Players are matched via ELO-based matchmaking; the first to get the AI to ask them on a date (or highest vibe at timeout) wins.

## Commands

```bash
# Run the app (production Firebase)
flutter run

# Run with Firebase emulators
flutter run --dart-define=USE_EMULATORS=true

# Run with mock providers (no Firebase needed, UI walkthrough only)
flutter run -t lib/main_mock.dart -d macos

# Analyze
flutter analyze

# Cloud Functions (from functions/ directory)
cd functions && npm run build    # compile TypeScript
cd functions && npm run serve    # run emulators locally
```

## Architecture

### Flutter App (`lib/`)

**State management**: Riverpod (`flutter_riverpod`). All providers live in `lib/core/providers/`.

**Routing**: GoRouter with `StatefulShellRoute.indexedStack` for the bottom nav tabs (Dashboard, Leaderboard, Challengers, History, Profile). Auth redirect logic in `lib/core/router.dart` — unauthenticated users go to `/login`, authenticated users redirect from `/login` to `/dashboard`.

**Feature structure**: `lib/features/{feature}/presentation/` for pages, `lib/features/{feature}/data/` for services. Core shared code in `lib/core/` (models, services, providers, widgets, theme).

**Key data flow**:
- `firebase_providers.dart` — singleton providers for FirebaseAuth, Firestore, RTDB, Functions, plus derived providers (`authStateProvider`, `currentUserProvider`, `aiModelsProvider`, `matchHistoryProvider`)
- `match_providers.dart` — match-specific streams: `liveMatchStreamProvider` (RTDB), `firestoreMatchStreamProvider`, `messagesStreamProvider`, `presenceProvider`
- `mock_providers.dart` — provider overrides for `main_mock.dart` entry point

**Hybrid database pattern**:
- **Firestore**: user profiles (`users/`), match records (`matches/`), chat messages (`matches/{id}/players/{uid}/messages/`), AI model configs (`ai_models/`)
- **RTDB**: live match state (`active_states/{matchId}` — vibe scores, typing indicators), presence (`presence/{uid}`)

### Cloud Functions (`functions/src/`)

TypeScript, Firebase Functions v2. Key exports from `index.ts`:
- `onUserMessageSent` — Firestore trigger on new chat messages. Pipeline: load AI character → Gemini generates reply → Gemini judges user message (Turn Score) → update RTDB vibe → check win condition
- `findMatch` / `leaveQueue` — HTTPS callables for matchmaking (ELO ±150 range, optional geohash proximity)
- `cleanupExpiredMatchmaking` / `checkMatchTimeouts` — scheduled functions

Scoring formula: `Turn Score = [(Base Good × Persona Mult) × Timing Mult] − Base Bad`

AI model: `gemini-3.1-flash-lite-preview` for both chat and scoring. API key in `functions/.env`.

## Deployment

```bash
# Deploy all Cloud Functions
firebase deploy --only functions

# Deploy security rules
firebase deploy --only firestore:rules,database

# Deploy indexes
firebase deploy --only firestore:indexes

# Seed AI models (requires GOOGLE_APPLICATION_CREDENTIALS)
cd functions && npx ts-node src/seedAiModels.ts
```

Firebase project: `rizzrank-f52cd`, Node.js 22 runtime.

## Design Conventions

- Dark theme with purple primary (`#895AF6`), background `#151022`
- Glassmorphism pattern: `ClipRRect` + `BackdropFilter(blur: 10)` + `Container(color: white.withOpacity(0.05), border: white.withOpacity(0.1))`. Reusable widget at `lib/core/widgets/glass_card.dart`
- Google Fonts Inter for text theme
- Lucide icons (`lucide_icons` package)
- Chat auto-scroll: `ScrollController.animateTo` in `addPostFrameCallback`, 300ms `easeOut`
