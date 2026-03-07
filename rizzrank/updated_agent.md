# Agent Mission: RizzRank Mobile Transformation (v2.0)

... [Previous directives] ...

## New Development Requirements
1.  **Test-Driven Porting**: For every screen ported, a corresponding widget test must be created in `/test/widgets/`.
2.  **Tool Creation**: Before implementing the Chat UI, create the `test_gemini.dart` tool to ensure the AI logic is functional in the Dart environment.
3.  **Skill Application**: Refer to `.cursor/skills/` for specific implementation patterns regarding UI and UX.

## Final Success Criteria
- [ ] App compiles for both iOS (Swift) and Android (Kotlin/Gradle).
- [ ] `flutter analyze` returns zero issues.
- [ ] Integration test "Full Rizz Flow" passes.
- [ ] All code from the `rizzrank-mockup/` web folder is deleted.