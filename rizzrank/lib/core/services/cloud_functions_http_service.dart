import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP-based Cloud Functions client.
///
/// Replaces the cloud_functions plugin to avoid iOS FirebaseFunctionsPlugin
/// registration crash. Calls callable functions via direct HTTP requests.
class CloudFunctionsHttpService {
  CloudFunctionsHttpService(this._auth);

  final FirebaseAuth _auth;

  static const _projectId = 'rizzrank-f52cd';
  static const _region = 'us-central1';

  static String _baseUrl() {
    const useEmulators = bool.fromEnvironment(
      'USE_EMULATORS',
      defaultValue: false,
    );
    if (kDebugMode && useEmulators) {
      return 'http://localhost:5001/$_projectId/$_region';
    }
    return 'https://$_region-$_projectId.cloudfunctions.net';
  }

  /// Calls a callable Cloud Function by name.
  ///
  /// Returns the `result` field from the response, or null if no user is signed in.
  /// Throws on HTTP or function errors.
  Future<T?> call<T>(String name, [Map<String, dynamic>? args]) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken(true);
    final url = Uri.parse('${_baseUrl()}/$name');
    final body = jsonEncode({'data': args ?? {}});

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    if (decoded == null) {
      throw CloudFunctionsHttpException(
        status: response.statusCode,
        message: response.body,
      );
    }

    if (decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>?;
      final message = err?['message'] as String? ?? response.body;
      final status = err?['status'] as String? ?? 'UNKNOWN';
      throw CloudFunctionsHttpException(
        status: response.statusCode,
        message: message,
        functionStatus: status,
      );
    }

    if (response.statusCode >= 400) {
      throw CloudFunctionsHttpException(
        status: response.statusCode,
        message: decoded['message'] as String? ?? response.body,
      );
    }

    final result = decoded['result'];
    return result as T?;
  }
}

class CloudFunctionsHttpException implements Exception {
  CloudFunctionsHttpException({
    required this.status,
    required this.message,
    this.functionStatus,
  });

  final int status;
  final String message;
  final String? functionStatus;

  @override
  String toString() => 'CloudFunctionsHttpException: $status $message';
}
