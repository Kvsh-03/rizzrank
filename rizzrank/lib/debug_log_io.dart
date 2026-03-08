import 'dart:async';
import 'dart:convert';
import 'dart:io';

void debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  Future<void> sendLog() async {
    try {
      final payload = {
        "sessionId": "778642",
        "location": location,
        "message": message,
        "data": data,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "hypothesisId": hypothesisId,
      };
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(
          'http://127.0.0.1:7293/ingest/fdaaead6-5499-4685-ae85-ea78697384f7'));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('X-Debug-Session-Id', '778642');
      req.write(jsonEncode(payload));
      await req.close();
      client.close();
    } catch (_) {}
  }
  unawaited(sendLog());
}
