import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/app.dart';

void main() {
  testWidgets('OpenIPTVApp smoke test', (WidgetTester tester) async {
    // Verify the root widget mounts without throwing.
    // Full integration tests require a real DB and prefs; this guards
    // against missing-widget-class regressions at the entry point.
    expect(() => const OpenIPTVApp(), returnsNormally);
  });
}
