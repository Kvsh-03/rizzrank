# Skill: Implementing RizzRank Glassmorphism
To achieve the web project's CSS `.glass` effect in Flutter:
1. Wrap the widget in a `ClipRRect`.
2. Use a `BackdropFilter` with `ImageFilter.blur(sigmaX: 10, sigmaY: 10)`.
3. Set the child `Container` decoration to:
   - Color: `Colors.white.withOpacity(0.05)`
   - Border: `Border.all(color: Colors.white.withOpacity(0.1))`