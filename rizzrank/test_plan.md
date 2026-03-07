# RizzRank Testing Strategy

The AI Agent must implement the following test suites before declaring the migration complete:

## 1. Unit Tests (`test/unit/`)
- **ELO Logic**: Test the ELO change calculator (e.g., +25 for win, -12 for loss).
- **Model Parsing**: Ensure JSON from the Express API (or local DB) maps correctly to Dart Classes.
- **AI Service**: Mock the Gemini API and verify the message history formatting.

## 2. Widget Tests (`test/widgets/`)
- **Dashboard**: Verify user ELO and Win Rate are displayed accurately.
- **Chat**: Ensure the "Rizz Score" indicator appears when a user sends a message.
- **Navigation**: Test that the Bottom Nav Bar routes to the correct screens.

## 3. Integration Tests (`integration_test/`)
- **The "Full Rizz" Flow**: 
    1. Login -> Dashboard.
    2. Dashboard -> Matchmaking.
    3. Matchmaking -> Chat (wait 3 seconds).
    4. Chat -> Send 3 messages -> Results Page.
    5. Verify ELO increased in local storage.

## 4. Golden Tests
- Create visual snapshots of the `GlassCard` and `AffectionMeter` to ensure the Cyberpunk aesthetic is consistent across iOS and Android.