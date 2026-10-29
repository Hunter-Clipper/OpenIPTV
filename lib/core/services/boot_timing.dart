// Startup timing marks for the web build: they show up in the browser's
// Performance panel and in the "[OTV-boot]" summary logged on the first frame
// (see web/index.html). A no-op everywhere else.
export 'boot_timing_stub.dart' if (dart.library.html) 'boot_timing_web.dart';
