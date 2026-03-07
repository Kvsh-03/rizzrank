import 'package:firebase_database/firebase_database.dart';

/// Firebase-ready chat message for RTDB path:
/// matches/{matchId}/players/{uid}/messages/{pushId}/
class ChatMessage {
  final String? key;
  final String role;
  final String text;
  final int timestamp;
  final int? rizzDelta;

  const ChatMessage({
    this.key,
    required this.role,
    required this.text,
    required this.timestamp,
    this.rizzDelta,
  });

  factory ChatMessage.fromSnapshot(DataSnapshot snapshot) {
    final key = snapshot.key;
    final value = snapshot.value;
    if (value == null || value is! Map) {
      throw ArgumentError('Invalid message snapshot: expected Map');
    }
    final map = Map<String, dynamic>.from(value);
    return ChatMessage.fromMap(key, map);
  }

  factory ChatMessage.fromMap(String? key, Map<String, dynamic> map) {
    return ChatMessage(
      key: key,
      role: map['role'] as String? ?? 'user',
      text: map['text'] as String? ?? '',
      timestamp: _parseInt(map['timestamp'], 0),
      rizzDelta: map['rizz_delta'] != null
          ? _parseInt(map['rizz_delta'], 0)
          : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'text': text,
      'timestamp': timestamp,
      if (rizzDelta != null) 'rizz_delta': rizzDelta,
    };
  }

  ChatMessage copyWith({
    String? key,
    String? role,
    String? text,
    int? timestamp,
    int? rizzDelta,
  }) {
    return ChatMessage(
      key: key ?? this.key,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      rizzDelta: rizzDelta ?? this.rizzDelta,
    );
  }
}
