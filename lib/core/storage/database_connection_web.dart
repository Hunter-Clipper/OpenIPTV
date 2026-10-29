// Web connection to the app database: SQLite compiled to WebAssembly, kept in
// the browser's own storage (OPFS or IndexedDB, whichever it offers). There is
// no SQLCipher here — see docs/design/web.md; logins sit in browser storage.
//
// Needs web/sqlite3.wasm and web/drift_worker.js (matching the sqlite3 and
// drift versions in pubspec.lock).
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/services/boot_timing.dart';

QueryExecutor openAppConnection({bool migrate = true}) {
  return LazyDatabase(() async {
    bootMark('otv-db-open');
    final result = await WasmDatabase.open(
      databaseName: 'open_iptv',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    debugPrint('[OTV-db] web storage: ${result.chosenImplementation.name}'
        '${result.missingFeatures.isEmpty ? '' : ' (missing: ${result.missingFeatures.join(', ')})'}');
    bootMark('otv-db-ready');
    return result.resolvedExecutor;
  });
}
