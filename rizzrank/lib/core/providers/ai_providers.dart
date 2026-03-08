import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';
import '../services/database_service.dart';
import 'firebase_providers.dart';

/// Stream of all AI agents from Firestore ai_models.
final aiModelsProvider = StreamProvider<List<AIModel>>((ref) {
  return ref.watch(databaseServiceProvider).watchAIModels();
});

/// Resolves an AI agent by ID. Uses aiModelsProvider cache when possible,
/// otherwise fetches once. Returns a placeholder if not found.
final aiModelByIdProvider = FutureProvider.family<AIModel, String>((ref, id) async {
  final models = ref.watch(aiModelsProvider).value;
  if (models != null) {
    for (final m in models) {
      if (m.id == id) return m;
    }
  }
  final model = await ref.read(databaseServiceProvider).getAIModelById(id);
  return model ?? AIModel.placeholder(id);
});
