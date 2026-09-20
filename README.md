# RizzRank 💬⚡

> An AI-driven interactive conversation game that stress-tests your charisma, wit, and conversational agility in real time. Built with Flutter, Firebase, and the Google Gemini API.



---

## Overview

**RizzRank** turns conversational chemistry into a dynamic, gamified simulation. Users engage in interactive dialogue scenarios against distinct AI personas—each configured with unique personality traits, mood meters, and patience thresholds. Every message you send is dynamically evaluated using multimodal prompt pipelines to measure wit, confidence, situational awareness, and banter quality.

Whether practicing icebreakers or seeing how long you can hold a conversation under pressure, RizzRank delivers instantaneous feedback, qualitative breakdowns, and ranked scoring.

---

## Key Features

- **Dynamic Persona Simulation:** AI interlocutors adapt their tone, interest level, and responses on the fly based on conversational context and sentiment.
- **Multi-Vector Scoring Engine:** Evaluates inputs across key dimensions:
  - *Charisma & Charm* (delivery, tone, and appeal)
  - *Wit & Humor* (timing, wordplay, and banter responsiveness)
  - *Confidence* (directness vs. awkward hesitation)
  - *Contextual Awareness* (listening, callback ability, and empathy)
- **Post-Session Diagnostic Breakdown:** Receive a comprehensive post-round report detailing your peak lines, conversational blunders, and targeted tips for improvement.
- **Global & Friends Leaderboards:** Real-time ranking tiers synced via Firebase to track skill progression.
- **Cross-Platform Experience:** Responsive, fluid UI built from the ground up in Flutter for mobile and web.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter / Dart |
| **State Management** | Riverpod / Provider |
| **LLM & Inference** | Google Gemini API (`gemini-1.5-flash` / `gemini-1.5-pro`) |
| **Backend & Database** | Firebase Firestore |
| **Authentication** | Firebase Auth (Google Sign-In, Anonymous Guest) |
| **Hosting & Deployment** | Firebase Hosting |

---

## System Architecture

```text
┌─────────────────┐       User Input       ┌────────────────────────┐
│  Flutter Client │ ─────────────────────> │ Firebase / Proxy Layer │
│   (UI & State)  │                        └──────────┬─────────────┘
└────────┬────────┘                                   │
         │                                            │ Evaluates Input &
         │ Renders Response                           │ Maintains Persona Context
         │ & Score Deliberations                      ▼
         │                                 ┌────────────────────────┐
         └──────────────────────────────── │   Google Gemini API    │
                                           │  (Dialogue & Scoring)  │
                                           └────────────────────────┘
