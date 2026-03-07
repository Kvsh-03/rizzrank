# Setup Flutter environment
flutter pub add flutter_riverpod google_generative_ai isar isar_flutter_libs lucide_icons google_fonts animations sqflite path_provider dev:isar_generator dev:build_runner

# Create directory structure
mkdir -p lib/core/{theme,widgets,services}
mkdir -p lib/features/{auth,dashboard,chat,matchmaking,leaderboard,profile}/{presentation,data,domain}
mkdir -p docs
mkdir -p .cursor/skills
mkdir -p test/{unit,widgets}