import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/match_model.dart';
import '../models/firestore_match_model.dart';
import '../models/user_model.dart';
import 'firebase_providers.dart';
import 'match_providers.dart';

/// Mock Firebase User for UI walk-through without real auth.
final _mockFirebaseUser = MockUser(
  uid: 'mock-uid-123',
  email: 'mock@rizzrank.dev',
  displayName: 'Mock Player',
  isAnonymous: false,
);

/// Mock AppUser for Dashboard and BattlePage.
const _mockAppUser = AppUser(
  uid: 'mock-uid-123',
  displayName: 'Mock Player',
  rizzTitle: 'Smooth Operator',
  eloRating: 1250,
  totalGames: 42,
  wins: 28,
  losses: 14,
  createdAt: 1700000000,
);

/// Mock GameMatch for BattlePage live match display.
GameMatch _mockGameMatch(String matchId) => GameMatch(
      matchId: matchId,
      status: 'active',
      aiCharacterId: 'luna',
      playerIds: ['mock-uid-123', 'ai-opponent'],
      targetPhrase: 'Make them laugh',
      players: {
        'mock-uid-123': const PlayerState(
          uid: 'mock-uid-123',
          displayName: 'Mock Player',
          rizzScore: 65,
          isWinner: false,
        ),
        'ai-opponent': const PlayerState(
          uid: 'ai-opponent',
          displayName: 'Luna',
          rizzScore: 72,
          isWinner: false,
        ),
      },
    );

/// Mock FirestoreMatch for BattlePage completion listener.
FirestoreMatch _mockFirestoreMatch(String matchId) => FirestoreMatch(
      matchId: matchId,
      playerIds: ['mock-uid-123', 'ai-opponent'],
      status: 'active',
      targetPhrase: 'Make them laugh',
      aiCharacterId: 'luna',
    );

/// Mock chat messages for BattlePage.
final _mockMessages = [
  const ChatMessage(
    key: 'msg1',
    role: 'ai',
    text: "Hey! I've been thinking about that film we discussed. What's your take on the ending?",
    timestamp: 1700000000,
    rizzDelta: null,
  ),
  const ChatMessage(
    key: 'msg2',
    role: 'user',
    text: "I thought it was ambiguous on purpose – leaves room for interpretation.",
    timestamp: 1700000010,
    rizzDelta: 5,
  ),
  const ChatMessage(
    key: 'msg3',
    role: 'ai',
    text: "Exactly! That's what makes it memorable. Not everything needs a neat resolution.",
    timestamp: 1700000020,
    rizzDelta: null,
  ),
];

/// Provider overrides for UI walk-through without Firebase.
/// Use with ProviderScope(overrides: mockProviderOverrides).
List<Override> get mockProviderOverrides => [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateProvider.overrideWith(
        (ref) => Stream.value(_mockFirebaseUser),
      ),
      currentUserProvider.overrideWith(
        (ref) => Stream.value(_mockAppUser),
      ),
      liveMatchStreamProvider.overrideWith(
        (ref, matchId) => Stream.value(_mockGameMatch(matchId)),
      ),
      firestoreMatchStreamProvider.overrideWith(
        (ref, matchId) => Stream.value(_mockFirestoreMatch(matchId)),
      ),
      messagesStreamProvider.overrideWith(
        (ref, params) => Stream.value(_mockMessages),
      ),
    ];
