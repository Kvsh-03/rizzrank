import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore chat message for matches/{matchId}/chat/{autoId}.
///
/// Clients create user messages (role='user') with their own sender_uid.
/// Cloud Functions create AI replies (role='model') with sender_uid='ai_{characterId}'.
class ChatMessage {
  final String? key;
  final String senderUid;
  final String role;
  final String content;
  final int? tokenCount;
  final int timestamp;
  final int? rizzDelta;

  const ChatMessage({
    this.key,
    required this.senderUid,
    required this.role,
    required this.content,
    this.tokenCount,
    required this.timestamp,
    this.rizzDelta,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage.fromMap(doc.id, data);
  }

  factory ChatMessage.fromMap(String? key, Map<String, dynamic> map) {
    final tsRaw = map['timestamp'];
    int timestamp;
    if (tsRaw is Timestamp) {
      timestamp = tsRaw.millisecondsSinceEpoch;
    } else if (tsRaw is int) {
      timestamp = tsRaw;
    } else {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }

    return ChatMessage(
      key: key,
      senderUid: map['sender_uid'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      content: map['content'] as String? ?? map['text'] as String? ?? '',
      tokenCount: map['token_count'] != null
          ? _parseInt(map['token_count'], 0)
          : null,
      timestamp: timestamp,
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

  /// Firestore write payload for client-created user messages.
  Map<String, dynamic> toFirestore() {
    return {
      'sender_uid': senderUid,
      'role': role,
      'content': content,
      if (tokenCount != null) 'token_count': tokenCount,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  ChatMessage copyWith({
    String? key,
    String? senderUid,
    String? role,
    String? content,
    int? tokenCount,
    int? timestamp,
    int? rizzDelta,
  }) {
    return ChatMessage(
      key: key ?? this.key,
      senderUid: senderUid ?? this.senderUid,
      role: role ?? this.role,
      content: content ?? this.content,
      tokenCount: tokenCount ?? this.tokenCount,
      timestamp: timestamp ?? this.timestamp,
      rizzDelta: rizzDelta ?? this.rizzDelta,
    );
  }
}
