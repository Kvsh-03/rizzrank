# Agent Tooling Requirements

The AI Agent must generate and use the following local tools during development:

## 1. Schema Validator (`bin/validate_models.dart`)
Create a Dart script that:
- Iterates through `lib/core/models/`.
- Validates that every model has `fromJson`, `toJson`, and `copyWith` methods.
- Ensures all models are compatible with the local database schema (Isar/SQLite).

## 2. Gemini Connectivity Tester (`bin/test_gemini.dart`)
Create a tool to:
- Load the `.env` API key.
- Send a "Hello" ping to the Gemini model.
- Verify that the character system instructions from `geminiService.ts` are correctly interpreted by the Dart SDK.

## 3. Rizz-Style UI Auditor
The AI should use a tool (or specific prompt sequence) to:
- Compare the `design_spec.md` with the generated Flutter code.
- Specifically check for the presence of `BackdropFilter` and `BoxShadow` in "Glass" components.