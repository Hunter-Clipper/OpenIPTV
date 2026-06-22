import 'package:flutter/material.dart';

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

  // Phase 2 will wire up actual Android TV detection via device_info_plus.
  // For Phase 1 (Android phone/tablet only), always returns false.
  static bool _isTV() => false;
}
