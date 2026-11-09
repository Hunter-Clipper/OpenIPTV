import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:open_iptv/shared/utils/motion.dart';

/// Butter-smooth mouse-wheel scrolling for the browser and desktop app.
///
/// A wheel notch arrives as one big jump (about 100 px), so lists lurch in
/// steps. This sits in front of Flutter's pointer input and, for a notch,
/// replaces that one jump with many small scroll events spread over a
/// fraction of a second that ease out. They go through the normal hit test,
/// so every list, row and nested scroller behaves as before — they just move
/// smoothly. Trackpads already send small, frequent deltas and pass through
/// untouched, and so does everything when Reduce Animations is on.
class SmoothWheel {
  SmoothWheel._();

  /// How quickly the scroll catches up with the wheel (smaller = snappier).
  static const _tau = 0.09; // seconds
  // A wheel notch is ~100 px; trackpad deltas are far smaller.
  static const _notchMin = 40.0;

  static bool _installed = false;
  static ui.PointerDataPacketCallback? _original;

  static Offset _remaining = Offset.zero;
  static Offset _position = Offset.zero;
  static int _viewId = 0;
  static int _device = 0;
  static Duration _lastFrame = Duration.zero;
  static bool _running = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    final dispatcher = ui.PlatformDispatcher.instance;
    _original = dispatcher.onPointerDataPacket;
    dispatcher.onPointerDataPacket = _onPacket;
  }

  static void _onPacket(ui.PointerDataPacket packet) {
    final original = _original;
    if (original == null) return;
    if (reduceMotion) return original(packet);
    final keep = <ui.PointerData>[];
    var changed = false;
    for (final d in packet.data) {
      final isNotch = d.signalKind == ui.PointerSignalKind.scroll &&
          d.kind == ui.PointerDeviceKind.mouse &&
          (d.scrollDeltaX.abs() >= _notchMin ||
              d.scrollDeltaY.abs() >= _notchMin);
      if (!isNotch) {
        keep.add(d);
        continue;
      }
      changed = true;
      final dpr = _devicePixelRatio(d.viewId);
      _position = Offset(d.physicalX, d.physicalY) / dpr;
      _viewId = d.viewId;
      _device = d.device;
      // Same direction rules as Flutter: deltas are physical pixels.
      _remaining += Offset(d.scrollDeltaX, d.scrollDeltaY) / dpr;
      _start();
    }
    if (!changed) return original(packet);
    if (keep.isNotEmpty) original(ui.PointerDataPacket(data: keep));
  }

  static double _devicePixelRatio(int viewId) {
    final view = ui.PlatformDispatcher.instance.view(id: viewId) ??
        ui.PlatformDispatcher.instance.implicitView;
    return view?.devicePixelRatio ?? 1.0;
  }

  static void _start() {
    if (_running) return;
    _running = true;
    _lastFrame = Duration.zero;
    SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }

  static void _tick(Duration now) {
    final dt = _lastFrame == Duration.zero
        ? 1 / 60
        : math.min((now - _lastFrame).inMicroseconds / 1e6, 0.05);
    _lastFrame = now;
    // Exponential ease-out: each frame covers a share of what is left.
    final share = 1 - math.exp(-dt / _tau);
    var step = _remaining * share;
    var done = false;
    if (_remaining.distance < 1.0) {
      step = _remaining;
      done = true;
    }
    _remaining -= step;
    if (step != Offset.zero) {
      GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        timeStamp: now,
        viewId: _viewId,
        device: _device,
        position: _position,
        scrollDelta: step,
      ));
    }
    if (done) {
      _remaining = Offset.zero;
      _running = false;
    } else {
      SchedulerBinding.instance.scheduleFrameCallback(_tick);
    }
  }
}
