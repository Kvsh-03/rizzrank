import 'package:cloud_firestore/cloud_firestore.dart';

/// AI agent model from Firestore ai_models collection.
/// Path: ai_models/{agentId}
///
/// Display fields for Flutter UI: id, name, role, description, avatarUrl.
/// Server-side fields (Cloud Functions): system_prompt, personality_summary.
class AIModel {
  final String id;
  final String name;
  final String role;
  final String description;
  final String avatarUrl;

  const AIModel({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.avatarUrl,
  });

  /// Placeholder when agent not found in Firebase.
  factory AIModel.placeholder(String id) {
    return AIModel(
      id: id,
      name: id,
      role: 'AI Agent',
      description: '',
      avatarUrl: '',
    );
  }

  factory AIModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final id = doc.id;
    if (data == null) {
      return AIModel(id: id, name: id, role: '', description: '', avatarUrl: '');
    }
    return AIModel(
      id: id,
      name: data['name'] as String? ?? id,
      role: data['role'] as String? ?? '',
      description: data['description'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String? ?? data['avatarUrl'] as String? ?? '',
    );
  }
}
