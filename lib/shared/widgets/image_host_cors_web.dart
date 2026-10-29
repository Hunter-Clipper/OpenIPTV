import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// One answer per image host, asked once. A host that refuses logs one
// console error here instead of one for every picture it serves.
final _byOrigin = <String, Future<bool>>{};

Future<bool> imageHostAllowsCors(String url) {
  final String origin;
  try {
    origin = Uri.parse(url).origin;
  } catch (_) {
    return Future.value(true);
  }
  return _byOrigin.putIfAbsent(origin, () => _probe(url));
}

Future<bool> _probe(String url) async {
  try {
    final init = JSObject()
      ..setProperty('mode'.toJS, 'cors'.toJS)
      ..setProperty('cache'.toJS, 'force-cache'.toJS);
    final response = await (globalContext
            .callMethod<JSPromise<JSAny?>>('fetch'.toJS, url.toJS, init))
        .toDart
        .timeout(const Duration(seconds: 8));
    return response != null;
  } catch (_) {
    // Blocked, offline or too slow: use the plain <img> route, which works
    // for any host.
    return false;
  }
}
