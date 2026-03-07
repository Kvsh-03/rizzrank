import 'package:flutter_test/flutter_test.dart';
import 'package:rizzrank/core/models/chat_message.dart';
import 'package:rizzrank/core/models/firestore_match_model.dart';
import 'package:rizzrank/core/models/match_model.dart';
import 'package:rizzrank/core/models/user_model.dart';

void main() {
  group('AppUser', () {
    test('fromMap parses user data correctly', () {
      final user = AppUser.fromMap('user123', {
        'display_name': 'TestUser',
        'elo_rating': 1200,
        'rizz_title': 'Diamond',
        'wins': 5,
        'losses': 2,
        'total_games': 7,
        'created_at': 1700000000000,
      });
      expect(user.uid, 'user123');
      expect(user.displayName, 'TestUser');
      expect(user.eloRating, 1200);
      expect(user.rizzTitle, 'Diamond');
      expect(user.wins, 5);
      expect(user.losses, 2);
      expect(user.totalGames, 7);
      expect(user.createdAt, 1700000000000);
    });

    test('toMap produces correct structure', () {
      const user = AppUser(
        uid: 'u1',
        displayName: 'Alice',
        eloRating: 1000,
        wins: 3,
        losses: 1,
      );
      final map = user.toMap();
      expect(map['display_name'], 'Alice');
      expect(map['elo_rating'], 1000);
      expect(map['wins'], 3);
      expect(map['losses'], 1);
    });

    test('copyWith works correctly', () {
      const user = AppUser(
        uid: 'u1',
        displayName: 'Bob',
        eloRating: 1000,
      );
      final updated = user.copyWith(eloRating: 1100, wins: 1);
      expect(updated.uid, 'u1');
      expect(updated.displayName, 'Bob');
      expect(updated.eloRating, 1100);
      expect(updated.wins, 1);
    });
  });

  group('ChatMessage', () {
    test('fromMap parses message data correctly', () {
      final msg = ChatMessage.fromMap('msg_abc', {
        'role': 'user',
        'text': 'Hello!',
        'timestamp': 1700000000000,
        'rizz_delta': 8,
      });
      expect(msg.key, 'msg_abc');
      expect(msg.role, 'user');
      expect(msg.text, 'Hello!');
      expect(msg.timestamp, 1700000000000);
      expect(msg.rizzDelta, 8);
    });

    test('toMap produces correct structure', () {
      const msg = ChatMessage(
        role: 'model',
        text: 'Hi there!',
        timestamp: 1700000000000,
      );
      final map = msg.toMap();
      expect(map['role'], 'model');
      expect(map['text'], 'Hi there!');
      expect(map['timestamp'], 1700000000000);
    });
  });

  group('PlayerState', () {
    test('fromMap parses player data correctly', () {
      final state = PlayerState.fromMap('player1', {
        'display_name': 'Challenger',
        'rizz_score': 45,
        'is_winner': false,
      });
      expect(state.uid, 'player1');
      expect(state.displayName, 'Challenger');
      expect(state.rizzScore, 45);
      expect(state.isWinner, false);
    });

    test('toMap produces correct structure', () {
      const state = PlayerState(
        uid: 'p1',
        displayName: 'Alice',
        rizzScore: 75,
        isWinner: true,
      );
      final map = state.toMap();
      expect(map['display_name'], 'Alice');
      expect(map['rizz_score'], 75);
      expect(map['is_winner'], true);
    });
  });

  group('FirestoreMatch', () {
    test('fromMap parses match data correctly', () {
      final match = FirestoreMatch.fromMap('m1', {
        'player_ids': ['p1', 'p2'],
        'winner_id': 'p1',
        'status': 'completed',
        'target_phrase': 'coffee date',
      });
      expect(match.matchId, 'm1');
      expect(match.playerIds, ['p1', 'p2']);
      expect(match.winnerId, 'p1');
      expect(match.status, 'completed');
      expect(match.targetPhrase, 'coffee date');
    });
  });

  group('Model validation (fromMap/toMap/copyWith consistency)', () {
    test('AppUser roundtrip and copyWith', () {
      final user = AppUser.fromMap('u1', {
        'display_name': 'Test',
        'elo_rating': 1000,
        'total_games': 0,
      });
      final map = user.toMap();
      expect(map['display_name'], 'Test');
      final copy = user.copyWith(eloRating: 1100);
      expect(copy.eloRating, 1100);
    });
    test('ChatMessage roundtrip and copyWith', () {
      final msg = ChatMessage.fromMap('m1', {
        'role': 'user',
        'text': 'Hi',
        'timestamp': 0,
        'rizz_delta': 5,
      });
      final map = msg.toMap();
      expect(map['role'], 'user');
      final copy = msg.copyWith(rizzDelta: 10);
      expect(copy.rizzDelta, 10);
    });
    test('FirestoreMatch roundtrip and copyWith', () {
      final match = FirestoreMatch.fromMap('m1', {
        'player_ids': ['p1', 'p2'],
        'winner_id': 'p1',
        'status': 'completed',
        'target_phrase': 'date',
      });
      final map = match.toFirestore();
      expect(map['status'], 'completed');
      final copy = match.copyWith(status: 'active');
      expect(copy.status, 'active');
    });
  });

  group('GameMatch', () {
    test('getOpponentUid returns correct opponent', () {
      const match = GameMatch(
        matchId: 'm1',
        status: 'active',
        aiCharacterId: 'luna',
        playerIds: ['playerA', 'playerB'],
        players: {
          'playerA': PlayerState(
            uid: 'playerA',
            displayName: 'A',
            rizzScore: 50,
          ),
          'playerB': PlayerState(
            uid: 'playerB',
            displayName: 'B',
            rizzScore: 30,
          ),
        },
      );
      expect(match.getOpponentUid('playerA'), 'playerB');
      expect(match.getOpponentUid('playerB'), 'playerA');
    });
  });
}
