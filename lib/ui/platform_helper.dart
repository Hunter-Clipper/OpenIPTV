import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/device_info_channel.dart';

enum AppLayout { phone, tablet, tv }

class PlatformHelper {
  PlatformHelper._();

  static AppLayout getLayout(BuildContext context) {
    if (_isTV()) return AppLayout.tv;
    final width = MediaQuery.of(context).size.width;
    return width >= 600 ? AppLayout.tablet : AppLayout.phone;
  }

  static bool isTV(BuildContext context) => getLayout(context) == AppLayout.tv;

  static bool isTablet(BuildContext context) =>
      getLayout(context) == AppLayout.tablet;

  static bool isPhone(BuildContext context) =>
      getLayout(context) == AppLayout.phone;

  /// Returns the number of poster grid columns for the current layout.
  static int posterColumns(BuildContext context) {
    switch (getLayout(context)) {
      case AppLayout.phone:
        return 2;
      case AppLayout.tablet:
        return 4;
      case AppLayout.tv:
        return 5;
    }
  }

  static bool? _cachedIsTv;

  /// Queries native Android once (via a UiModeManager MethodChannel) and
  /// caches the result. Call before runApp() so isTV() is correct from the
  /// very first frame; defaults to false (phone/tablet layout) if queried
  /// before this completes.
  static Future<void> initTvDetection() async {
    _cachedIsTv = await isTelevisionDevice();
  }

  static bool _isTV() => _cachedIsTv ?? false;
}
