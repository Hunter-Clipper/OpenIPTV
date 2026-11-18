import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';

/// Terminal green's tuning screen (#178): console output scrolling past as a
/// channel connects, a blinking cursor on the last line. One timer adds a
/// line every ~100 ms; nothing else animates.
class TerminalLoading extends StatefulWidget {
  const TerminalLoading({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  State<TerminalLoading> createState() => _TerminalLoadingState();
}

class _TerminalLoadingState extends State<TerminalLoading> {
  static const _keep = 40;
  final _rnd = math.Random();
  final _lines = <String>[];
  Timer? _timer;
  var _tick = 0;

  String _hex(int n) =>
      List.generate(n, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();

  String _next() {
    final n = _tick++;
    final id = _rnd.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    switch (n % 9) {
      case 0:
        return '> resolve host ... ok';
      case 1:
        return '[ ok ] socket 0x$id opened';
      case 2:
        return '0x${(n * 16).toRadixString(16).padLeft(4, '0')}  ${_hex(8)}';
      case 3:
        return 'demux pid=0x${(0x100 + _rnd.nextInt(8)).toRadixString(16)} sync ok';
      case 4:
        return '0x${(n * 16).toRadixString(16).padLeft(4, '0')}  ${_hex(8)}';
      case 5:
        final p = (_rnd.nextInt(90) + 5);
        return 'buffer ${'#' * (p ~/ 10)}${'.' * (10 - p ~/ 10)} $p%';
      case 6:
        return 'probe codec ... h264 / aac';
      case 7:
        return '0x${(n * 16).toRadixString(16).padLeft(4, '0')}  ${_hex(8)}';
      default:
        return 'frame queue ${_rnd.nextInt(30)} pkts';
    }
  }

  @override
  void initState() {
    super.initState();
    _lines.add('> tune --channel "${widget.name}"');
    _timer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() {
        _lines.add(_next());
        if (_lines.length > _keep) _lines.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(builder: (context, box) {
        final size = box.maxHeight < 300 ? 9.0 : 15.0;
        final blink = (DateTime.now().millisecond ~/ 500).isEven;
        return ClipRect(
          child: Padding(
            padding: EdgeInsets.all(size),
            child: ListView.builder(
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lines.length,
              itemBuilder: (context, i) {
                final index = _lines.length - 1 - i;
                final last = index == _lines.length - 1;
                // Older lines fade out towards the top.
                final alpha = (1 - i * 0.045).clamp(0.2, 1.0);
                return Text(
                  last ? '${_lines[index]} ${blink ? '\u2588' : ' '}' : _lines[index],
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: size,
                    height: 1.3,
                    color: widget.color.withValues(alpha: alpha),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

/// The tuning screen of whichever terminal look is on: console output for
/// Terminal green, a dial-up modem handshake for Amber.
class TuningScreen extends StatelessWidget {
  const TuningScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final look = Theme.of(context).extension<GuideStyle>();
    if (look == null) return const SizedBox.shrink();
    if (look.amberLoader) {
      return ModemLoading(name: name, color: look.titleColor);
    }
    return TerminalLoading(name: name, color: look.titleColor);
  }
}

/// Amber's tuning screen (#178): an old dial-up modem handshake, then the
/// channel's name with a filling meter. One looping controller; no assets.
class ModemLoading extends StatefulWidget {
  const ModemLoading({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  State<ModemLoading> createState() => _ModemLoadingState();
}

class _ModemLoadingState extends State<ModemLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(builder: (context, box) {
        final fs = box.maxHeight < 300 ? 9.0 : 16.0;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 8; // seconds, looping
            final name = widget.name.toUpperCase();
            final dots = '.' * ((t * 3).floor() % 4);
            final meter = ((t - 2.4) / 5 * 14).floor().clamp(0, 14);
            final lines = <String>[
              'ATDT 555-0142',
              if (t < 0.8) 'DIALING$dots' else 'DIALING... OK',
              if (t > 0.8) 'CONNECT 14400',
              if (t > 1.6) 'CARRIER 14400/ARQ',
              if (t > 2.4) '> $name',
              if (t > 2.4)
                '[${'#' * meter}${'.' * (14 - meter)}] ${(meter / 14 * 100).round()}%',
            ];
            return Padding(
              padding: EdgeInsets.all(fs),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  lines.join('\n'),
                  maxLines: 8,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: fs,
                    height: 1.35,
                    color: widget.color,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
