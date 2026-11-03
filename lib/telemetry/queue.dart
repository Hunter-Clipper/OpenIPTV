// A small on-device queue of reports waiting to be sent (#150). Plain JSON
// in one file, so "See exactly what is sent" can show it as it is.

import 'dart:convert';
import 'dart:io';

/// The most reports kept; older ones are dropped first.
const maxQueuedReports = 20;

class ReportQueue {
  ReportQueue(this.file);

  final File file;

  Future<List<Map<String, dynamic>>> read() async {
    try {
      if (!await file.exists()) return [];
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return [];
      return data.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(Map<String, dynamic> report) async {
    final all = await read()..add(report);
    final kept = all.length > maxQueuedReports
        ? all.sublist(all.length - maxQueuedReports)
        : all;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(kept));
  }

  Future<void> replace(List<Map<String, dynamic>> reports) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(reports));
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
