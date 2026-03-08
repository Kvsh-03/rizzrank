#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

/// Validates that all models in lib/core/models/ have the required methods:
/// - Parse: fromMap, fromSnapshot, or fromFirestore
/// - Serialize: toMap or toFirestore
/// - copyWith
///
/// Run: dart run bin/validate_models.dart

import 'package:rizzrank/core/models/chat_message.dart';
import 'package:rizzrank/core/models/firestore_match_model.dart';
import 'package:rizzrank/core/models/match_model.dart';
import 'package:rizzrank/core/models/user_model.dart';

void main() {
  var passed = 0;
  var failed = 0;

  // AppUser
  try {
    final user = AppUser.fromMap('u1', {
      'display_name': 'Test',
      'elo_rating': 1000,
      'total_games': 0,
    });
    final map = user.toFirestore();
    if (map['display_name'] != 'Test') throw StateError('toFirestore mismatch');
    final clientMap = user.toClientFirestore();
    if (clientMap.containsKey('elo_rating')) {
      throw StateError('toClientFirestore should not contain elo_rating');
    }
    final copy = user.copyWith(eloRating: 1100);
    if (copy.eloRating != 1100) throw StateError('copyWith mismatch');
    print('PASS: AppUser (fromMap, toFirestore, toClientFirestore, copyWith)');
    passed++;
  } catch (e, st) {
    print('FAIL: AppUser - $e');
    print(st);
    failed++;
  }

  // ChatMessage
  try {
    final msg = ChatMessage.fromMap('m1', {
      'sender_uid': 'user1',
      'role': 'user',
      'content': 'Hi',
      'timestamp': 0,
      'rizz_delta': 5,
    });
    final map = msg.toFirestore();
    if (map['role'] != 'user') throw StateError('toFirestore mismatch');
    if (map['content'] != 'Hi') throw StateError('content mismatch');
    final copy = msg.copyWith(rizzDelta: 10);
    if (copy.rizzDelta != 10) throw StateError('copyWith mismatch');
    print('PASS: ChatMessage (fromMap, toFirestore, copyWith)');
    passed++;
  } catch (e, st) {
    print('FAIL: ChatMessage - $e');
    print(st);
    failed++;
  }

  // ActiveMatchState
  try {
    final state = ActiveMatchState.fromMap('m1', {
      'status': 'active',
      'player_ids': ['p1', 'p2'],
      'p1_vibe': 50,
      'p2_vibe': 30,
      'is_typing': 'p1',
    });
    if (state.vibeFor('p1') != 50) throw StateError('vibeFor p1 mismatch');
    if (state.vibeFor('p2') != 30) throw StateError('vibeFor p2 mismatch');
    if (state.getOpponentUid('p1') != 'p2') throw StateError('getOpponentUid mismatch');
    if (state.isCompleted) throw StateError('should not be completed');
    print('PASS: ActiveMatchState (fromMap, vibeFor, getOpponentUid, isCompleted)');
    passed++;
  } catch (e, st) {
    print('FAIL: ActiveMatchState - $e');
    print(st);
    failed++;
  }

  // FirestoreMatch
  try {
    final match = FirestoreMatch.fromMap('m1', {
      'player_ids': ['p1', 'p2'],
      'winner_id': 'p1',
      'status': 'completed',
      'target_phrase': 'date',
      'ai_traits': {'personality_traits': 'Witty'},
      'elo_change': {'p1': 25, 'p2': -12},
    });
    final map = match.toFirestore();
    if (map['status'] != 'completed') throw StateError('toFirestore mismatch');
    if (match.aiTraits['personality_traits'] != 'Witty') throw StateError('aiTraits mismatch');
    if (match.eloChange['p1'] != 25) throw StateError('eloChange mismatch');
    final copy = match.copyWith(status: 'active');
    if (copy.status != 'active') throw StateError('copyWith mismatch');
    print('PASS: FirestoreMatch (fromMap, toFirestore, aiTraits, eloChange, copyWith)');
    passed++;
  } catch (e, st) {
    print('FAIL: FirestoreMatch - $e');
    print(st);
    failed++;
  }

  print('');
  print('--- Summary ---');
  print('Passed: $passed');
  print('Failed: $failed');
  if (failed > 0) {
    exit(1);
  }
  print('All models validated successfully.');
}
