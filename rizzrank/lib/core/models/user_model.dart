import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// User profile model for Firestore users collection and RTDB compatibility.
/// Firestore path: users/{uid}
///
/// Server-managed fields (Cloud Functions only):
///   elo_rating, total_games, wins, losses, active_match_id, leaderboard_rank.
/// Client-managed fields: display_name, rizz_title, preferred_gender, last_played.
class AppUser {
  final String uid;
  final String displayName;
  final String rizzTitle;
  final int eloRating;
  final int totalGames;
  final int wins;
  final int losses;
  final DateTime? lastPlayed;
  final int? createdAt;
  final String? activeMatchId;
  final String? preferredGender;
  final int? leaderboardRank;

  const AppUser({
    required this.uid,
    required this.displayName,
    this.rizzTitle = 'Rookie',
    this.eloRating = 1000,
    this.totalGames = 0,
    this.wins = 0,
    this.losses = 0,
    this.lastPlayed,
    this.createdAt,
    this.activeMatchId,
    this.preferredGender,
    this.leaderboardRank,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final uid = doc.id;
    if (data == null) {
      return AppUser(uid: uid, displayName: '');
    }
    return AppUser.fromMap(uid, data);
  }

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
    DateTime? lastPlayed;
    final lpRaw = map['last_played'] ?? map['lastPlayed'];
    if (lpRaw is Timestamp) {
      lastPlayed = lpRaw.toDate();
    } else if (lpRaw is int) {
      lastPlayed = DateTime.fromMillisecondsSinceEpoch(lpRaw);
    }

    return AppUser(
      uid: uid,
      displayName:
          map['display_name'] as String? ?? map['displayName'] as String? ?? '',
      rizzTitle:
          map['rizz_title'] as String? ?? map['rizzTitle'] as String? ?? 'Rookie',
      eloRating: _parseInt(map['elo_rating'] ?? map['elo'], 1000),
      totalGames: _parseInt(map['total_games'] ?? map['totalMatches'], 0),
      wins: _parseInt(map['wins'], 0),
      losses: _parseInt(map['losses'], 0),
      lastPlayed: lastPlayed,
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? _parseInt(map['created_at'] ?? map['createdAt'], 0)
          : null,
      activeMatchId:
          map['active_match_id'] as String? ?? map['activeMatchId'] as String?,
      preferredGender:
          map['preferred_gender'] as String? ?? map['preferredGender'] as String?,
      leaderboardRank: map['leaderboard_rank'] != null
          ? _parseInt(map['leaderboard_rank'], 0)
          : map['leaderboardRank'] != null
              ? _parseInt(map['leaderboardRank'], 0)
              : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Full Firestore representation (used by Cloud Functions / Admin SDK).
  Map<String, dynamic> toFirestore() {
    return {
      'display_name': displayName,
      'rizz_title': rizzTitle,
      'elo_rating': eloRating,
      'total_games': totalGames,
      'wins': wins,
      'losses': losses,
      'last_played': lastPlayed != null
          ? Timestamp.fromDate(lastPlayed!)
          : FieldValue.serverTimestamp(),
      if (createdAt != null) 'created_at': createdAt,
      if (activeMatchId != null) 'active_match_id': activeMatchId,
      if (preferredGender != null) 'preferred_gender': preferredGender,
      if (leaderboardRank != null) 'leaderboard_rank': leaderboardRank,
    };
  }

  /// Client-safe Firestore write -- excludes server-managed fields
  /// (elo_rating, total_games, wins, losses, active_match_id, leaderboard_rank).
  Map<String, dynamic> toClientFirestore() {
    return {
      'display_name': displayName,
      'rizz_title': rizzTitle,
      'last_played': FieldValue.serverTimestamp(),
      if (preferredGender != null) 'preferred_gender': preferredGender,
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
    DateTime? lastPlayed,
    int? createdAt,
    String? activeMatchId,
    String? preferredGender,
    int? leaderboardRank,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      rizzTitle: rizzTitle ?? this.rizzTitle,
      eloRating: eloRating ?? this.eloRating,
      totalGames: totalGames ?? this.totalGames,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      createdAt: createdAt ?? this.createdAt,
      activeMatchId: activeMatchId ?? this.activeMatchId,
      preferredGender: preferredGender ?? this.preferredGender,
      leaderboardRank: leaderboardRank ?? this.leaderboardRank,
    );
  }
}
