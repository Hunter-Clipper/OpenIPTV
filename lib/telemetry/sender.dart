// Sends queued reports (#150): one HTTPS POST per report to the project's
// own receiver (tools/stats-worker). No cookies, no headers beyond the
// content type, nothing else in the request.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where reports go. Replace with the deployed Worker address
/// (see tools/stats-worker/README.md). While it still holds the placeholder,
/// nothing is sent and reports simply stay in the queue.
const statsEndpoint = 'https://openiptv-stats.example.workers.dev/report';

bool get statsEndpointConfigured => !statsEndpoint.contains('example.workers.dev');

/// Sends [reports] one by one; returns the ones that were NOT accepted so the
/// caller can keep them for next time.
Future<List<Map<String, dynamic>>> sendReports(
  List<Map<String, dynamic>> reports, {
  http.Client? client,
  String endpoint = statsEndpoint,
}) async {
  final c = client ?? http.Client();
  final failed = <Map<String, dynamic>>[];
  try {
    for (final r in reports) {
      try {
        final res = await c
            .post(Uri.parse(endpoint),
                headers: const {'content-type': 'application/json'},
                body: jsonEncode(r))
            .timeout(const Duration(seconds: 15));
        // 2xx = stored. 4xx = the receiver will never accept it: drop it.
        // 5xx / network trouble = try again later.
        if (res.statusCode >= 500) failed.add(r);
      } catch (_) {
        failed.add(r);
      }
    }
  } finally {
    if (client == null) c.close();
  }
  return failed;
}
