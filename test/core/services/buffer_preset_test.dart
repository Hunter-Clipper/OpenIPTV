import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';

void main() {
  test('unknown or missing ids fall back to Fast start', () {
    expect(BufferPreset.fromId(null), BufferPreset.fast);
    expect(BufferPreset.fromId('huge'), BufferPreset.fast);
    expect(BufferPreset.fromId('smooth'), BufferPreset.smooth);
  });

  test('bigger buffers get a more patient watchdog', () {
    const p = BufferPreset.values;
    for (var i = 1; i < p.length; i++) {
      expect(p[i].freezeLimit, greaterThan(p[i - 1].freezeLimit));
      expect(p[i].connectLimit, greaterThan(p[i - 1].connectLimit));
    }
    // Fast start keeps the long-standing watchdog timings.
    expect(BufferPreset.fast.freezeLimit, const Duration(seconds: 4));
    expect(BufferPreset.fast.connectLimit, const Duration(seconds: 8));
  });

  test('ids are unique (they are stored and sent to the player)', () {
    final ids = BufferPreset.values.map((p) => p.id).toSet();
    expect(ids.length, BufferPreset.values.length);
  });
}
