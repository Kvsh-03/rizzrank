import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/match_model.dart';
import '../models/firestore_match_model.dart';
import '../models/user_model.dart';
import 'firebase_providers.dart';
import 'match_providers.dart';

final _mockFirebaseUser = MockUser(
  uid: 'mock-uid-123',
  email: 'mock@rizzrank.dev',
  displayName: 'Mock Player',
  isAnonymous: false,
);

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

ActiveMatchState _mockActiveMatch(String matchId) => ActiveMatchState(
      matchId: matchId,
      status: 'active',
      aiCharacterId: 'luna',
      playerIds: const ['mock-uid-123', 'ai-opponent'],
      targetPhrase: 'Make them laugh',
      p1Vibe: 65,
      p2Vibe: 72,
    );

FirestoreMatch _mockFirestoreMatch(String matchId) => FirestoreMatch(
      matchId: matchId,
      playerIds: const ['mock-uid-123', 'ai-opponent'],
      status: 'active',
      targetPhrase: 'Make them laugh',
      aiCharacterId: 'luna',
    );

final _mockMessages = [
  const ChatMessage(
    key: 'msg1',
    senderUid: 'ai_luna',
    role: 'model',
    content: "Hey! I've been thinking about that film we discussed. What's your take on the ending?",
    timestamp: 1700000000,
  ),
  const ChatMessage(
    key: 'msg2',
    senderUid: 'mock-uid-123',
    role: 'user',
    content: "I thought it was ambiguous on purpose – leaves room for interpretation.",
    timestamp: 1700000010,
    rizzDelta: 5,
  ),
  const ChatMessage(
    key: 'msg3',
    senderUid: 'ai_luna',
    role: 'model',
    content: "Exactly! That's what makes it memorable. Not everything needs a neat resolution.",
    timestamp: 1700000020,
  ),
];

/// Provider overrides for UI walk-through without Firebase.
List<Override> get mockProviderOverrides => [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateProvider.overrideWith(
        (ref) => Stream.value(_mockFirebaseUser),
      ),
      currentUserProvider.overrideWith(
        (ref) => Stream.value(_mockAppUser),
      ),
      liveMatchStreamProvider.overrideWith(
        (ref, matchId) => Stream.value(_mockActiveMatch(matchId)),
      ),
      firestoreMatchStreamProvider.overrideWith(
        (ref, matchId) => Stream.value(_mockFirestoreMatch(matchId)),
      ),
      messagesStreamProvider.overrideWith(
        (ref, params) => Stream.value(_mockMessages),
      ),
    ];
