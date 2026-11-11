import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';

void main() {
  test('overlayAlpha keeps the normal look, solid is opaque, others thin it',
      () {
    expect(overlayAlpha('normal', 0.96), 0.96);
    expect(overlayAlpha('solid', 0.96), 1.0);
    expect(overlayAlpha('clear', 0.96), lessThan(0.96));
    expect(overlayAlpha('veryclear', 0.96), lessThan(overlayAlpha('clear', 0.96)));
  });

  test('scrimAlpha strengthens on solid and never leaves 0..1', () {
    expect(scrimAlpha('normal', 0.5), 0.5);
    expect(scrimAlpha('solid', 0.5), greaterThan(0.5));
    expect(scrimAlpha('solid', 0.95), 1.0);
    expect(scrimAlpha('solid', 0.0), 0.0);
    expect(scrimAlpha('veryclear', 0.5), lessThan(scrimAlpha('clear', 0.5)));
  });
}
