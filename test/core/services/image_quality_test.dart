import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/image_quality.dart';

Future<(int, int?, int)> _probe(WidgetTester t, {required bool? full}) async {
  late int w;
  int? h;
  late int backdrop;
  final child = Builder(builder: (context) {
    w = context.imageDecodeWidth(300);
    h = context.imageDecodeHeight(240);
    backdrop = context.imageDecodeWidth(1080,
        fullMax: ImageQuality.fullMaxBackdropWidth);
    return const SizedBox();
  });
  await t.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: full == null ? child : ImageQuality(full: full, child: child),
  ));
  return (w, h, backdrop);
}

void main() {
  testWidgets('standard keeps each picture at its drawn size', (t) async {
    final (w, h, b) = await _probe(t, full: false);
    expect((w, h, b), (300, 240, 1080));
  });

  testWidgets('no scope behaves as standard', (t) async {
    final (w, h, b) = await _probe(t, full: null);
    expect((w, h, b), (300, 240, 1080));
  });

  testWidgets('full decodes wide and keeps the picture\'s own shape',
      (t) async {
    final (w, h, b) = await _probe(t, full: true);
    expect(w, ImageQuality.fullMaxWidth);
    expect(h, isNull);
    expect(b, ImageQuality.fullMaxBackdropWidth);
  });

  testWidgets('full never shrinks a picture that was already bigger',
      (t) async {
    late int w;
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ImageQuality(
        full: true,
        child: Builder(builder: (context) {
          w = context.imageDecodeWidth(1920);
          return const SizedBox();
        }),
      ),
    ));
    expect(w, 1920);
  });

  testWidgets('flipping the setting rebuilds dependents', (t) async {
    var builds = 0;
    final key = GlobalKey<_HostState>();
    await t.pumpWidget(_Host(key: key, onBuild: () => builds++));
    expect(builds, 1);
    key.currentState!.set(true);
    await t.pump();
    expect(builds, 2);
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.onBuild});
  final VoidCallback onBuild;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool full = false;
  void set(bool v) => setState(() => full = v);
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: ImageQuality(
          full: full,
          child: Builder(builder: (context) {
            context.imageDecodeWidth(300);
            widget.onBuild();
            return const SizedBox();
          }),
        ),
      );
}
