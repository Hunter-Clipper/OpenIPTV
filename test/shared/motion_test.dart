import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/utils/motion.dart';

void main() {
  testWidgets('animations collapse only when the system asks for none',
      (tester) async {
    const d = Duration(milliseconds: 300);
    expect(motionDuration(d), d);
    expect(reduceMotion, isFalse);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    expect(reduceMotion, isTrue);
    expect(motionDuration(d), Duration.zero);
  });
}
