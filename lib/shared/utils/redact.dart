/// A URL safe to write to the log: Xtream path logins
/// (`/live/<user>/<pass>/…`), `username=` / `password=` query values and
/// `user:pass@` hosts are masked. Logcat is readable over adb, so provider
/// logins never go there in clear text.
String redactUrl(String url) => url
    .replaceAllMapped(
        RegExp(r'/(live|movie|series|timeshift)/[^/]+/[^/]+/'),
        (m) => '/${m[1]}/***/***/')
    .replaceAllMapped(RegExp(r'((?:user(?:name)?|pass(?:word)?)=)[^&#]*',
        caseSensitive: false), (m) => '${m[1]}***')
    .replaceAllMapped(RegExp(r'(://)[^/@]+@'), (m) => '${m[1]}***@');
