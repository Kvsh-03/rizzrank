/// AI character data for UI display.
/// System instructions live server-side only (Cloud Functions).
class AICharacter {
  final String id;
  final String name;
  final String role;
  final String description;
  final String avatarUrl;
  final int difficulty;

  const AICharacter({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.avatarUrl,
    this.difficulty = 3,
  });
}

const List<AICharacter> kAICharacters = [
  AICharacter(
    id: 'luna',
    name: 'Luna',
    role: 'Film Student',
    description: 'Moody & Articulate. Loves 70s noir and niche cinematography.',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
    difficulty: 3,
  ),
  AICharacter(
    id: 'atlas',
    name: 'Atlas',
    role: 'Mechanical Android',
    description: 'Logical but curious about human emotion.',
    avatarUrl:
        'https://images.unsplash.com/photo-1546776310-eef45dd6d63c?auto=format&fit=crop&q=80&w=200&h=200',
    difficulty: 4,
  ),
  AICharacter(
    id: 'zephyr',
    name: 'Zephyr',
    role: 'Neon Strategist',
    description: 'Fast-paced, high energy, and loves competition.',
    avatarUrl:
        'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&q=80&w=200&h=200',
    difficulty: 2,
  ),
];

AICharacter getCharacterById(String id) {
  return kAICharacters.firstWhere(
    (c) => c.id == id,
    orElse: () => kAICharacters.first,
  );
}
