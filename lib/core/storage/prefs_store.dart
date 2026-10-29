// Cross-platform key/value store for [AppPreferences] (see
// preferences.dart). Native wraps SharedPreferences; web writes straight to
// the browser's localStorage.
//
// The web branch exists because shared_preferences_web is not registered in
// this Flutter web build — dart2js tree-shakes the generated plugin
// registrant, so SharedPreferences's MethodChannel calls are silent no-ops
// and nothing would persist. Pointing the store at localStorage keeps
// profiles/sources/settings saved across reloads on web.
export 'prefs_store_native.dart' if (dart.library.html) 'prefs_store_web.dart';
