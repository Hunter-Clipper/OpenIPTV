import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/graphics_mode.dart';

void main() {
  test('unknown or missing ids fall back to Automatic', () {
    expect(GraphicsModeSetting.fromId(null), GraphicsModeSetting.automatic);
    expect(GraphicsModeSetting.fromId('vulkan'), GraphicsModeSetting.automatic);
    expect(GraphicsModeSetting.fromId('compat'),
        GraphicsModeSetting.compatibility);
    expect(GraphicsModeSetting.fromId('standard'), GraphicsModeSetting.standard);
  });

  test('ids are unique (they are stored natively)', () {
    final ids = GraphicsModeSetting.values.map((m) => m.id).toSet();
    expect(ids.length, GraphicsModeSetting.values.length);
  });

  GraphicsModeInfo info(String setting, String active, String autoUses) =>
      GraphicsModeInfo.fromMap({
        'setting': setting,
        'active': active,
        'autoWouldUse': autoUses,
      })!;

  test('a restart is needed only when the wanted mode differs from the one in use',
      () {
    // Automatic on a known-bad TV that already runs compatible: nothing to do.
    expect(info('auto', 'compat', 'compat').needsRestart, isFalse);
    // Automatic on a normal device: standard.
    expect(info('auto', 'standard', 'standard').needsRestart, isFalse);
    // The user picks Standard on the TV that auto-ran compatible.
    expect(info('standard', 'compat', 'compat').needsRestart, isTrue);
    // The user picks Compatible on a normal device.
    expect(info('compat', 'standard', 'standard').needsRestart, isTrue);
    // ...and it has been applied.
    expect(info('compat', 'compat', 'standard').needsRestart, isFalse);
  });

  test('chip line joins what the device reports', () {
    final i = GraphicsModeInfo.fromMap({
      'setting': 'auto',
      'active': 'standard',
      'autoWouldUse': 'standard',
      'socModel': 'AMLS905X5M',
      'boardPlatform': 's7d',
    })!;
    expect(i.chip, 'AMLS905X5M · s7d');
    expect(info('auto', 'standard', 'standard').chip, isNull);
  });

  test('a missing or malformed reply is no info', () {
    expect(GraphicsModeInfo.fromMap(null), isNull);
    expect(GraphicsModeInfo.fromMap('x'), isNull);
  });
}
