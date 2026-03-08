# AI Models (Agents) - Firestore Setup

The app now reads AI agents from Firestore instead of hardcoded data. Add documents to the **`ai_models`** collection to define your agents.

## Firestore Schema: `ai_models/{agentId}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Display name (e.g. "Luna") |
| `role` | string | Yes | Short role/title (e.g. "Film Student") |
| `description` | string | No | Longer description for UI |
| `avatar_url` | string | No | Image URL for avatar (or `avatarUrl`) |
| `system_prompt` | string | Yes* | System instruction for the AI model (Cloud Functions) |
| `personality_summary` | string | No | Personality summary (Cloud Functions) |

*`system_prompt` and `personality_summary` are used by Cloud Functions for Gemini. If missing, the server falls back to hardcoded character configs.

## Example Document

**Collection:** `ai_models`  
**Document ID:** `luna` (or any unique ID)

```json
{
  "name": "Luna",
  "role": "Film Student",
  "description": "Moody & Articulate. Loves 70s noir and niche cinematography.",
  "avatar_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200",
  "system_prompt": "You are Luna, a moody and articulate film student...",
  "personality_summary": "Moody, articulate, loves cinema"
}
```

## Matchmaking

The Cloud Function `findMatch` picks a random agent from `ai_models`. If the collection is empty, it falls back to `luna`, `atlas`, or `zephyr` (create those docs to avoid placeholder UI).

## Where Agents Are Used

- **Challengers tab**: Lists all agents from `ai_models`
- **Battle page**: Shows the agent assigned to the match
- **History tab**: Resolves `ai_character_id` from each match to display agent info
- **Solo battle**: Uses agent by ID from the route
