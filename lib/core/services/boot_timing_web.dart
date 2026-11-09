import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void bootMark(String name) {
  try {
    final perf = globalContext.getProperty<JSObject?>('performance'.toJS);
    perf?.callMethodVarArgs<JSAny?>('mark'.toJS, [name.toJS]);
  } catch (_) {
    // Timing is best-effort; never let it break startup.
  }
}
