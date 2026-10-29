import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:open_iptv/shared/widgets/brand_splash.dart' show kBrandInk;

/// Names the browser tab while this widget is on screen: "Movies · OpenIPTV".
/// Web only — on Android it does nothing (the same call would rename the app
/// in the recents list).
///
/// Several can be alive at once (a movie page open over the Movies tab), so
/// each registers itself and the newest one wins; when it goes away the title
/// falls back to the page underneath. (Flutter's own `Title` can't do that:
/// it only writes when it is built, so popping a page left the old title.)
class PageTitle extends StatefulWidget {
  const PageTitle(this.title, {super.key, required this.child});

  /// The page's name; null or empty leaves just "OpenIPTV".
  final String? title;
  final Widget child;

  @override
  State<PageTitle> createState() => _PageTitleState();
}

class _PageTitleState extends State<PageTitle> {
  static const _appName = 'OpenIPTV';
  static final _live = <_PageTitleState>[];

  @override
  void initState() {
    super.initState();
    _live.add(this);
    _apply();
  }

  @override
  void didUpdateWidget(PageTitle old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) _apply();
  }

  @override
  void dispose() {
    _live.remove(this);
    _apply();
    super.dispose();
  }

  static void _apply() {
    if (!kIsWeb) return;
    final title = _live.isEmpty ? null : _live.last.widget.title?.trim();
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: title == null || title.isEmpty ? _appName : '$title · $_appName',
        primaryColor: kBrandInk.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A page title for use inside a [CustomScrollView]: add it as the first
/// sliver of a screen whose title is only known once its data has loaded.
class SliverPageTitle extends StatelessWidget {
  const SliverPageTitle(this.title, {super.key});

  final String? title;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: PageTitle(title, child: const SizedBox.shrink()),
      );
}
