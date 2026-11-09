import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Runs [work] on a background isolate so big parses don't block the UI.
/// Browsers have no isolates (`Isolate.run` throws there), so on web it runs
/// in place.
Future<T> runOffMain<T>(FutureOr<T> Function() work, {String? debugName}) =>
    kIsWeb ? Future<T>.sync(work) : Isolate.run<T>(work, debugName: debugName);
