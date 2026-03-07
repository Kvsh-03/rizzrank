import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// User profile model for Firestore users collection and RTDB compatibility.
/// Firestore path: users/{uid}
/// RTDB path: users/{uid} (legacy)
class AppUser {
  final String uid;
  final String displayName;
  final String rizzTitle;
  final int eloRating;
  final int totalGames;
  final int wins;
  final int losses;
  final int? createdAt;

  const AppUser({
    required this.uid,
    required this.displayName,
    this.rizzTitle = 'Rookie',
    this.eloRating = 1000,
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.createdAt,
  });

  /// Parses from Firestore DocumentSnapshot.
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final uid = doc.id;
    if (data == null) {
      return AppUser(uid: uid, displayName: '');
    }
    return AppUser.fromMap(uid, data);
  }

  /// Parses from RTDB DataSnapshot (legacy).
  factory AppUser.fromSnapshot(DataSnapshot snapshot) {
    final uid = snapshot.key ?? '';
    final value = snapshot.value;
    if (value == null || value is! Map) {
      throw ArgumentError('Invalid user snapshot: expected Map');
    }
    final map = Map<String, dynamic>.from(value);
    return AppUser.fromMap(uid, map);
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      displayName: map['display_name'] as String? ?? map['displayName'] as String? ?? '',
      rizzTitle: map['rizz_title'] as String? ?? map['rizzTitle'] as String? ?? 'Rookie',
      eloRating: _parseInt(map['elo_rating'] ?? map['elo'], 1000),
      totalGames: _parseInt(map['total_games'] ?? map['totalMatches'], 0),
      wins: _parseInt(map['wins'], 0),
      losses: _parseInt(map['losses'], 0),
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? _parseInt(map['created_at'] ?? map['createdAt'], 0)
          : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Firestore field names (snake_case for consistency with security rules).
  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'rizz_title': rizzTitle,
      'elo_rating': eloRating,
      'total_games': totalGames,
      'wins': wins,
      'losses': losses,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  AppUser copyWith({
    String? uid,
    String? displayName,
    String? rizzTitle,
    int? eloRating,
    int? totalGames,
    int? wins,
    int? losses,
    int? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      rizzTitle: rizzTitle ?? this.rizzTitle,
      eloRating: eloRating ?? this.eloRating,
      totalGames: totalGames ?? this.totalGames,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
