# Skill: Chat Auto-Scroll
When a new message is added to the `ListView`:
1. Use a `ScrollController`.
2. Trigger `_scrollController.animateTo` within a `WidgetsBinding.instance.addPostFrameCallback`.
3. Ensure the animation duration is `300ms` with `Curves.easeOut`.