# Planned UI Changes

## 1. Remove Challengers Tab

**Current:** The app has a "Challengers" tab in the bottom navigation where users can browse and select pre-made AI agents (e.g., Luna, Atlas, Zephyr).

**Change:** Remove the Challengers tab entirely.

**Reason:** The app uses solo matchmaking with randomly assigned AI agents (with random persona traits). Pre-made agent selection is no longer needed.

---

## 2. Player Profile – Match History

**Current:** The player profile/section displays hardcoded or sample match history data.

**Change:** Remove the hardcoded/sample match history from the player profile. Instead, surface the same historical matches shown on the "History" tab (i.e., use real Firestore match data).

**Reason:** A single source of truth for match history; avoid duplicate or fake data on the profile.
