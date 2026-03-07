import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/mock_providers.dart';
import 'main.dart' show RizzRankApp;

/// Entry point for UI walk-through with mock providers.
/// Run with: flutter run -t lib/main_mock.dart -d macos
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: mockProviderOverrides,
      child: const RizzRankApp(),
    ),
  );
}
