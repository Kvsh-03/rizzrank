import 'dart:convert';
import 'dart:io';

/// Debug session logging for agent instrumentation.
/// Writes NDJSON to .cursor/debug-9a87ae.log
void debugLog({
  required String location,
  required String message,
  Map<String, dynamic>? data,
  String? hypothesisId,
}) {
  try {
    final payload = {
      'sessionId': '9a87ae',
      'location': location,
      'message': message,
      if (data != null) 'data': data,
      if (hypothesisId != null) 'hypothesisId': hypothesisId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    const logPath = '/Users/kushjain/codingprojects/rizzrank/.cursor/debug-9a87ae.log';
    File(logPath).writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
  } catch (_) {}
}
