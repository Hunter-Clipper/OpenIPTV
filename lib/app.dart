import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/pip_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/channel_list_screen.dart';
import 'package:open_iptv/features/live_tv/tv_guide_screen.dart';
import 'package:open_iptv/features/movies/movie_detail_screen.dart';
import 'package:open_iptv/features/movies/movies_screen.dart';
import 'package:open_iptv/features/onboarding/add_source_screen.dart';
import 'package:open_iptv/features/onboarding/setup_wizard_screen.dart';
import 'package:open_iptv/features/player/player_screen.dart';
import 'package:open_iptv/features/search/search_screen.dart';
import 'package:open_iptv/features/series/episode_list_screen.dart';
import 'package:open_iptv/features/series/series_detail_screen.dart';
import 'package:open_iptv/features/series/series_screen.dart';
import 'package:open_iptv/features/settings/backup_screen.dart';
import 'package:open_iptv/features/settings/parental_screen.dart';
import 'package:open_iptv/features/settings/profile_picker_screen.dart';
import 'package:open_iptv/features/settings/profile_screen.dart';
import 'package:open_iptv/features/settings/settings_screen.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/shared/widgets/tv_nav_rail_focus.dart';
import 'package:open_iptv/ui/platform_helper.dart';

class OpenIPTVApp extends ConsumerStatefulWidget {
  const OpenIPTVApp({super.key});

  @override
  ConsumerState<OpenIPTVApp> createState() => _OpenIPTVAppState();
}

class _OpenIPTVAppState extends ConsumerState<OpenIPTVApp> {
  late final GoRouter _router;
  final _tooltipController = InfoTooltipController();
  bool _dbReady = false;
  // True once user has picked (or auto-selected) a profile this session.
  bool _profilePicked = false;
  // True when multiple profiles exist and user must actively choose.
  bool _needsProfilePick = false;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _openDb();
  }

  Future<void> _openDb() async {
    const maxAttempts = 5;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await ref.read(appDatabaseProvider).customSelect('SELECT 1').get();
        break;
      } catch (e) {
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    final db = ref.read(appDatabaseProvider);
    final prefs = await ref.read(appPreferencesProvider.future);

    // Re-sync the background auto-refresh registration against the
    // persisted interval — WorkManager can drop periodic registrations
    // across OS updates or force-stops, so this must run on every launch,
    // not just when the user changes the setting.
    unawaited(syncAutoRefreshRegistration(prefs));

    // Initialise accent + sort state from persisted preferences.
    syncSettingsProviders(ref, prefs);
    ref.read(activeSourceIdProvider.notifier).state = prefs.activeSourceId;

    initPipChannel(
      onPipModeChanged: (isInPip) =>
          ref.read(pipActiveProvider.notifier).state = isInPip,
    );
    void pushPipAvailability() {
      final playing = ref.read(playbackServiceProvider).lastState.playing;
      updatePipAvailability(ref.read(pipEnabledProvider) && playing);
    }
    pushPipAvailability();
    ref
        .read(playbackServiceProvider)
        .stateStream
        .listen((_) => pushPipAvailability());

    // Profile setup.
    final profiles = await db.getAllProfiles();
    if (profiles.length == 1) {
      // Auto-select single profile (no picker needed).
      await prefs.setActiveProfileId(profiles.first.id);
    }

    final needsPick = profiles.length > 1;

    if (mounted) {
      setState(() {
        _dbReady = true;
        _needsProfilePick = needsPick;
        _profilePicked = !needsPick;
      });
    }
  }

  @override
  void dispose() {
    _tooltipController.dispose();
    super.dispose();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/live',
      redirect: (context, state) async {
        final path = state.fullPath ?? '';
        if (path.startsWith('/setup') || path.startsWith('/onboarding')) {
          return null;
        }
        final db = ref.read(appDatabaseProvider);
        final profiles = await db.getAllProfiles();
        final sources = await db.getAllSources();
        if (profiles.isEmpty && sources.isEmpty) return '/setup';
        if (sources.isEmpty) return '/onboarding';

        if (path.startsWith('/settings/parental') ||
            path.startsWith('/settings/backup')) {
          final activeProfile = await ref.read(activeProfileProvider.future);
          if (activeProfile == null || !activeProfile.isAdmin) {
            return '/settings';
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/setup',
          builder: (_, __) => const SetupWizardScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const AddSourceScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => _Shell(child: child),
          routes: [
            GoRoute(
              path: '/live',
              builder: (_, __) => const ChannelListScreen(),
              routes: [
                GoRoute(
                  path: 'category/:cat',
                  builder: (_, state) => LiveCategoryScreen(
                    category: state.pathParameters['cat']!,
                  ),
                ),
                GoRoute(
                  path: 'guide',
                  builder: (_, __) => const TvGuideScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/movies',
              builder: (_, __) => const MoviesScreen(),
              routes: [
                GoRoute(
                  path: 'genre/:genre',
                  builder: (_, state) => MovieGenreScreen(
                    genre: state.pathParameters['genre']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/series',
              builder: (_, __) => const SeriesScreen(),
              routes: [
                GoRoute(
                  path: 'genre/:genre',
                  builder: (_, state) => SeriesGenreScreen(
                    genre: state.pathParameters['genre']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/search',
              builder: (_, __) => const SearchScreen(),
            ),
          ],
        ),
        // Detail pages on the root navigator so _RootNavObserver tracks depth
        // and Shell's back handler returns false (same as Settings/Player).
        GoRoute(
          path: '/movies/:id',
          builder: (_, state) =>
              MovieDetailScreen(movieId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/series/:id',
          builder: (_, state) =>
              SeriesDetailScreen(seriesId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'episodes',
              builder: (_, state) => EpisodeListScreen(
                seriesId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/player',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>;
            return PlayerScreen(
              streamUrl: extra['streamUrl'] as String,
              title: extra['title'] as String,
              contentId: extra['contentId'] as String?,
              contentType: extra['contentType'] as String?,
              resumePosition: extra['resumePosition'] as Duration?,
              seriesId: extra['seriesId'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'profiles',
              builder: (_, __) => const ProfileScreen(),
            ),
            GoRoute(
              path: 'backup',
              builder: (_, __) => const BackupScreen(),
            ),
            GoRoute(
              path: 'parental',
              builder: (_, __) => const ParentalScreen(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);

    if (!_dbReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Show profile picker before mounting the router when multiple
    // profiles exist and the user hasn't selected one this session.
    if (_needsProfilePick && !_profilePicked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(accent),
        darkTheme: AppTheme.dark(accent),
        themeMode: ThemeMode.dark,
        home: ProfilePickerScreen(
          onPicked: () => setState(() {
            _needsProfilePick = false;
            _profilePicked = true;
          }),
        ),
      );
    }

    return InfoTooltipScope(
      controller: _tooltipController,
      child: MaterialApp.router(
        title: 'OpenIPTV',
        theme: AppTheme.dark(accent),
        darkTheme: AppTheme.dark(accent),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  // Remembers which tab was active before the user navigated to Search.
  int _previousTabIndex = 0;

  // Root-tab back handling is done via a native MethodChannel rather than
  // Flutter's PopScope/OnBackInvokedCallback: empirically, a PopScope
  // wrapping this shell's content never actually stopped the system from
  // closing the Activity here, even hard-coded to canPop:false (verified via
  // an on-screen counter — its onPopInvokedWithResult callback never fired
  // before the app closed). Handling Back directly in MainActivity.kt
  // sidesteps whatever that mismatch was: Dart tells native whether a root
  // tab is showing (nothing left to pop, otherwise closing the app instead
  // of doing nothing), and native either lets the press through normally
  // (sub-routes like /movies/genre/action keep popping exactly as before)
  // or calls back into Dart to decide what "Back" should do here.
  static const _backChannel = MethodChannel('openiptv/back');
  bool? _lastReportedBlocked;

  // The currently-active tab's rail item — explicitly refocused as a
  // fallback when arrow-left has nowhere left to go within the content pane
  // (see EdgeAwareDirectionalFocusAction in tv_focusable.dart), rather than relying on
  // Flutter's default directional traversal to find it on its own — it
  // doesn't reliably jump from the content pane (often inside its own
  // scrollable grid/list) across into a separate sibling column like this
  // rail.
  final FocusNode _activeRailItemFocusNode =
      FocusNode(debugLabel: 'NavRailActiveItem');

  @override
  void initState() {
    super.initState();
    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'backPressed') _handleNativeBackPressed();
    });
  }

  @override
  void dispose() {
    _backChannel.setMethodCallHandler(null);
    _activeRailItemFocusNode.dispose();
    super.dispose();
  }

  void _handleNativeBackPressed() {
    if (!mounted) return;
    if (GoRouterState.of(context).uri.path != '/search') {
      // Live/Movies/Series root: absorb the press entirely — there's nowhere
      // for "back" to mean anything on a root tab.
      return;
    }
    if (searchFieldFocused.value) {
      // The search field itself was focused — hand focus to the rail
      // instead of leaving the tab outright.
      _activeRailItemFocusNode.requestFocus();
      return;
    }
    // Search tab: go back to whichever tab was active before it.
    context.go(_kNavDestinations[_previousTabIndex].path);
  }

  @override
  Widget build(BuildContext context) {
    void onBeforeNavigate(int currentIndex, int newIndex) {
      if (newIndex == 3 && currentIndex != 3) {
        setState(() => _previousTabIndex = currentIndex);
      }
    }

    // True only when sitting exactly at one of the tab roots (not a pushed
    // sub-route like /movies/genre/action, which the shell's own nested
    // Navigator still pops normally — native only intervenes when told to).
    final location = GoRouterState.of(context).uri.path;
    final isRootTab = _kNavDestinations.any((d) => d.path == location);
    if (_lastReportedBlocked != isRootTab) {
      _lastReportedBlocked = isRootTab;
      unawaited(_backChannel.invokeMethod('setBlocked', isRootTab));
    }

    if (PlatformHelper.isTV(context)) {
      return Scaffold(
        body: Actions(
          actions: {
            DirectionalFocusIntent: EdgeAwareDirectionalFocusAction(
              directions: {TraversalDirection.left},
              onNoMove: () => _activeRailItemFocusNode.requestFocus(),
            ),
          },
          child: Row(
            children: [
              _TvNavRail(
                onBeforeNavigate: onBeforeNavigate,
                activeItemFocusNode: _activeRailItemFocusNode,
              ),
              Expanded(
                child: TvNavRailFocus(
                  focusNode: _activeRailItemFocusNode,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _BottomNav(onBeforeNavigate: onBeforeNavigate),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tab destinations — one source of truth for phone bottom nav and TV
// side rail, so the two chrome styles can't drift out of sync.
// ---------------------------------------------------------------------------

class _NavDestination {
  const _NavDestination(this.icon, this.label, this.path);
  final IconData icon;
  final String label;
  final String path;
}

const _kNavDestinations = [
  _NavDestination(Icons.tv, 'Live TV', '/live'),
  _NavDestination(Icons.movie_outlined, 'Movies', '/movies'),
  _NavDestination(Icons.video_library_outlined, 'Series', '/series'),
  _NavDestination(Icons.search, 'Search', '/search'),
];

int _navIndexForLocation(BuildContext context) {
  final location = GoRouterState.of(context).fullPath ?? '/live';
  for (var i = _kNavDestinations.length - 1; i >= 0; i--) {
    if (location.startsWith(_kNavDestinations[i].path)) return i;
  }
  return 0;
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.onBeforeNavigate});

  final void Function(int currentIndex, int newIndex) onBeforeNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _navIndexForLocation(context);

    return BottomNavigationBar(
      currentIndex: index,
      onTap: (i) {
        onBeforeNavigate(index, i);
        context.go(_kNavDestinations[i].path);
      },
      items: [
        for (final d in _kNavDestinations)
          BottomNavigationBarItem(icon: Icon(d.icon), label: d.label),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TV side rail — replaces the bottom bar on Android TV. Hand-built (not
// Flutter's NavigationRail) so each destination is a chunky, obviously
// focusable TvFocusable target rather than NavigationRail's denser default
// touch-target sizing.
// ---------------------------------------------------------------------------

class _TvNavRail extends ConsumerWidget {
  const _TvNavRail({
    required this.onBeforeNavigate,
    required this.activeItemFocusNode,
  });

  final void Function(int currentIndex, int newIndex) onBeforeNavigate;
  // Attached to whichever destination is currently active, so the shell can
  // explicitly refocus the rail (arrow-left from the content pane) without
  // depending on Flutter's default directional traversal finding it.
  final FocusNode activeItemFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final index = _navIndexForLocation(context);

    return Container(
      width: 96,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _kNavDestinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _TvNavRailItem(
                  icon: _kNavDestinations[i].icon,
                  label: _kNavDestinations[i].label,
                  active: i == index,
                  // Only the very first item auto-claims focus, and only on
                  // the rail's initial mount (cold app start, landing on
                  // Live TV) — NOT `i == index`, which would re-fire
                  // autofocus on every navigation. `activeItemFocusNode` is
                  // still wired up below so the explicit arrow-left "escape
                  // to rail" fallback (EdgeAwareDirectionalFocusAction) can
                  // requestFocus() it on demand.
                  autofocus: i == 0,
                  focusNode: i == index ? activeItemFocusNode : null,
                  onTap: () {
                    // Explicitly drop focus from whichever rail item the
                    // user actually pressed select on — that item currently
                    // holds real focus on its OWN internal FocusNode (from
                    // D-pad navigation), separate from `activeItemFocusNode`.
                    // The moment this item becomes "active" a few lines
                    // above, its `focusNode` prop is swapped from that
                    // internal node onto the shared `activeItemFocusNode`
                    // instance — and Flutter's Focus widget carries a live
                    // "hasFocus" over across a focusNode swap by design, so
                    // without this the rail keeps real focus (and its glow
                    // pill lit) even after the destination screen autofocuses
                    // its own first item. Dropping focus first, before that
                    // swap/rebuild happens, leaves nothing to carry over.
                    FocusManager.instance.primaryFocus?.unfocus();
                    onBeforeNavigate(index, i);
                    context.go(_kNavDestinations[i].path);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// A soft glowing pill (rather than TvFocusable's default hard-edged border
// box) with a subtle scale pop on focus — reads as more deliberate/"designed"
// for a rail the user dwells on and arrows up/down through, vs. the generic
// ring used for one-off targets elsewhere in the app. Active-route coloring
// (icon/label tinted `colorScheme.primary` when this is the current screen)
// is untouched — that's driven entirely by `active`, independent of focus.
class _TvNavRailItem extends StatefulWidget {
  const _TvNavRailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<_TvNavRailItem> createState() => _TvNavRailItemState();
}

class _TvNavRailItemState extends State<_TvNavRailItem> {
  bool _focused = false;

  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final color =
        widget.active ? accent : theme.colorScheme.onSurfaceVariant;

    return TvFocusable(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      showFocusRing: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedScale(
        scale: _focused ? 1.08 : 1.0,
        duration: _duration,
        curve: _curve,
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: _focused
                ? accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 28, color: color),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: theme.textTheme.labelSmall!.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Root navigator observer — tracks how many routes are stacked above the shell
// ---------------------------------------------------------------------------

// Module-level singleton: one router, one root observer.
// ---------------------------------------------------------------------------

extension ProfileGear on BuildContext {
  void openSettings() => push('/settings');
}

