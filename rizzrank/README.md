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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
