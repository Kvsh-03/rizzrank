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

    test('toFirestore produces correct structure', () {
      const user = AppUser(
        uid: 'u1',
        displayName: 'Alice',
        eloRating: 1000,
        wins: 3,
        losses: 1,
      );
      final map = user.toFirestore();
      expect(map['display_name'], 'Alice');
      expect(map['elo_rating'], 1000);
      expect(map['wins'], 3);
      expect(map['losses'], 1);
    });

    test('toClientFirestore excludes server-managed fields', () {
      const user = AppUser(
        uid: 'u1',
        displayName: 'Alice',
        eloRating: 1200,
        wins: 10,
        losses: 5,
        totalGames: 15,
        rizzTitle: 'Diamond',
      );
      final map = user.toClientFirestore();
      expect(map.containsKey('display_name'), true);
      expect(map.containsKey('rizz_title'), true);
      expect(map.containsKey('elo_rating'), false);
      expect(map.containsKey('wins'), false);
      expect(map.containsKey('losses'), false);
      expect(map.containsKey('total_games'), false);
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
    test('fromMap parses message data with content field', () {
      final msg = ChatMessage.fromMap('msg_abc', {
        'sender_uid': 'user1',
        'role': 'user',
        'content': 'Hello!',
        'timestamp': 1700000000000,
        'rizz_delta': 8,
      });
      expect(msg.key, 'msg_abc');
      expect(msg.senderUid, 'user1');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello!');
      expect(msg.timestamp, 1700000000000);
      expect(msg.rizzDelta, 8);
    });

    test('fromMap falls back to text field for legacy data', () {
      final msg = ChatMessage.fromMap('msg_legacy', {
        'sender_uid': 'user1',
        'role': 'user',
        'text': 'Legacy message',
        'timestamp': 1700000000000,
      });
      expect(msg.content, 'Legacy message');
    });

    test('toFirestore produces correct structure', () {
      const msg = ChatMessage(
        senderUid: 'user1',
        role: 'model',
        content: 'Hi there!',
        timestamp: 1700000000000,
      );
      final map = msg.toFirestore();
      expect(map['sender_uid'], 'user1');
      expect(map['role'], 'model');
      expect(map['content'], 'Hi there!');
    });

    test('copyWith works correctly', () {
      const msg = ChatMessage(
        senderUid: 'u1',
        role: 'user',
        content: 'test',
        timestamp: 0,
        rizzDelta: 5,
      );
      final copy = msg.copyWith(rizzDelta: 10);
      expect(copy.rizzDelta, 10);
      expect(copy.content, 'test');
    });
  });

  group('ActiveMatchState', () {
    test('fromMap parses flat active_states data', () {
      final state = ActiveMatchState.fromMap('m1', {
        'status': 'active',
        'player_ids': ['p1', 'p2'],
        'ai_character_id': 'luna',
        'target_phrase': 'coffee date',
        'p1_vibe': 45,
        'p2_vibe': 30,
        'is_typing': 'p1',
        'winner_uid': null,
        'created_at': 1700000000000,
      });
      expect(state.matchId, 'm1');
      expect(state.status, 'active');
      expect(state.playerIds, ['p1', 'p2']);
      expect(state.p1Vibe, 45);
      expect(state.p2Vibe, 30);
      expect(state.isTyping, 'p1');
      expect(state.winnerUid, isNull);
    });

    test('vibeFor returns correct vibe by player index', () {
      const state = ActiveMatchState(
        matchId: 'm1',
        playerIds: ['playerA', 'playerB'],
        p1Vibe: 50,
        p2Vibe: 75,
      );
      expect(state.vibeFor('playerA'), 50);
      expect(state.vibeFor('playerB'), 75);
      expect(state.vibeFor('unknown'), 0);
    });

    test('getOpponentUid returns correct opponent', () {
      const state = ActiveMatchState(
        matchId: 'm1',
        playerIds: ['playerA', 'playerB'],
      );
      expect(state.getOpponentUid('playerA'), 'playerB');
      expect(state.getOpponentUid('playerB'), 'playerA');
    });

    test('isCompleted returns true for completed status', () {
      const active = ActiveMatchState(matchId: 'm1', status: 'active');
      const completed = ActiveMatchState(matchId: 'm2', status: 'completed');
      expect(active.isCompleted, false);
      expect(completed.isCompleted, true);
    });
  });

  group('FirestoreMatch', () {
    test('fromMap parses match data with new fields', () {
      final match = FirestoreMatch.fromMap('m1', {
        'player_ids': ['p1', 'p2'],
        'winner_id': 'p1',
        'status': 'completed',
        'target_phrase': 'coffee date',
        'ai_traits': {'personality_traits': 'Witty', 'moods': 'Happy'},
        'elo_change': {'p1': 25, 'p2': -12},
      });
      expect(match.matchId, 'm1');
      expect(match.playerIds, ['p1', 'p2']);
      expect(match.winnerId, 'p1');
      expect(match.status, 'completed');
      expect(match.aiTraits, {'personality_traits': 'Witty', 'moods': 'Happy'});
      expect(match.eloChange, {'p1': 25, 'p2': -12});
    });

    test('toFirestore roundtrip preserves data', () {
      final match = FirestoreMatch.fromMap('m1', {
        'player_ids': ['p1', 'p2'],
        'winner_id': 'p1',
        'status': 'completed',
        'target_phrase': 'date',
        'ai_traits': {'careers': 'Chef'},
        'elo_change': {'p1': 20, 'p2': -10},
      });
      final map = match.toFirestore();
      expect(map['status'], 'completed');
      expect(map['ai_traits'], {'careers': 'Chef'});
      expect(map['elo_change'], {'p1': 20, 'p2': -10});
    });

    test('copyWith works correctly', () {
      final match = FirestoreMatch.fromMap('m1', {
        'player_ids': ['p1', 'p2'],
        'status': 'active',
      });
      final copy = match.copyWith(status: 'completed', winnerId: 'p1');
      expect(copy.status, 'completed');
      expect(copy.winnerId, 'p1');
    });
  });
}
