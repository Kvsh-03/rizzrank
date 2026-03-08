# UI Deletions (This Branch)

A record of every UI element removed in this branch.

---

## 1. Sign-up / Login page

| Deleted | Description |
|--------|-------------|
| **Username field** | Text field with label "Username" and hint "your_handle" |
| **Sign In button** | Primary button that performed anonymous sign-in with the entered username |
| **Apple sign-in option** | "Apple" outlined button (social login row) |
| **"OR CONTINUE WITH" divider** | Divider with label between the Sign In button and social buttons |
| **"Don't have an account? Sign Up" row** | Bottom row with text and "Sign Up" text button |

**Left:** Only the **Continue with Google** button.

---

## 2. Profile tab

| Deleted | Description |
|--------|-------------|
| **LVL 42 badge** | Badge on the profile picture (bottom-right) showing "LVL 42" |
| **FAVORITE AGENT section** | Entire block: section title "FAVORITE AGENT", agent card with avatar, name (e.g. "Luna-7"), description "Seduction & Wit Specialist", affinity progress bar, "Affinity Level 85%", and sparkles icon |

---

## 3. Home page (Dashboard)

| Deleted | Description |
|--------|-------------|
| **Notification button** | Bell icon button in the top-right header |
| **Settings button** | Settings (gear) icon button in the top-right header (linked to `/preferences`) |
| **"Pick your opponent" section** | Full block: title "Pick your opponent", subtitle "Select an AI challenger, then tap Find Match", and the horizontal scrollable list of the 3 pre-created AI challengers (Luna, Atlas, Zephyr) with avatars and names |

---

## 4. History tab

| Deleted | Description |
|--------|-------------|
| **Reset / history icon** | Circular icon button in the top-right of the header (next to "Match History" title) |

---

## 5. Rank tab (Leaderboard page)

| Deleted | Description |
|--------|-------------|
| **".pro" text** | The ".pro" suffix next to "RizzRank" in the top ribbon (now shows only "RizzRank") |

---

## 6. Landing page (removed entirely)

| Deleted | Description |
|--------|-------------|
| **Landing page** | The first screen (RizzRank title, description, "Play Now" and "How It Works" buttons, and the AI avatar hero card). The app now opens directly on the Google sign-in page. |
| **"How it works" button** | Outlined button with info icon and label "How It Works" (was removed before the whole landing page was deleted) |

---

## 7. Login page (Google sign-in screen)

| Deleted | Description |
|--------|-------------|
| **Blue background circle** | Large circular glow (500×500, primary color at 20% opacity) behind the sign-in card |

---

## 8. Matchmaking page

| Deleted | Description |
|--------|-------------|
| **"YOUR CHAMPION" card** | Card showing the selected AI champion (name, role, avatar) and the "VS" divider above the "OPPONENT" card. Removed when the "Pick your opponent" flow was removed and matchmaking assigns the agent server-side. |

---

## 9. Data / content (no longer hardcoded)

| Deleted | Description |
|--------|-------------|
| **Hardcoded AI characters (Luna, Atlas, Zephyr)** | The 3 sample agents and `getCharacterById` / `kAICharacters` from `lib/core/data/ai_characters.dart`. Replaced by Firebase `ai_models` collection; Challengers, Battle, History, and Solo now use Firestore data (or placeholders if no doc exists). |
| **Mock match history** | History tab no longer uses `_mockHistory` (3 fake entries); it uses real match history from Firestore. |

---

## Summary by screen

- **Login:** Username, Sign In, Apple, divider, Sign Up row; blue circle.
- **Profile:** LVL 42 badge; Favorite Agent section.
- **Home:** Notification + Settings buttons; Pick your opponent block.
- **History:** Reset/history icon; mock data replaced by Firebase.
- **Rank:** ".pro" in ribbon.
- **Landing:** Entire page (including How it works).
- **Matchmaking:** Your Champion card.
- **App-wide:** Hardcoded AI character list and mock history.
