// Full screen for a browser tab (the F key in the player). Native builds
// ignore it. The conditional import keeps dart:html out of the Android build.
export 'browser_fullscreen_stub.dart'
    if (dart.library.html) 'browser_fullscreen_web.dart';
