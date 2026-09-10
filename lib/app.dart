import 'dart:async';

import 'package:flutter/material.dart';
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
      final playing = ref.read(playbackServiceProvider).player.state.playing;
      updatePipAvailability(ref.read(pipEnabledProvider) && playing);
    }
    pushPipAvailability();
    ref.read(playbackServiceProvider).player.stream.playing.listen(
        (_) => pushPipAvailability());

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

  @override
  Widget build(BuildContext context) {
    // NavigatorPopHandler wraps the inner Navigator from ShellRoute.
    // onPop fires only when the inner nav has nothing left to pop — i.e.
    // we're at a root tab (genre/category pages pop naturally before this).
    // Detail pages on the root navigator (movies/:id, settings, player)
    // pop via the root navigator and never reach onPop.
    void onBeforeNavigate(int currentIndex, int newIndex) {
      if (newIndex == 3 && currentIndex != 3) {
        setState(() => _previousTabIndex = currentIndex);
      }
    }

    final navigator = NavigatorPopHandler(
      onPopWithResult: (Object? result) {
        if (!mounted) return;
        final path =
            GoRouter.of(context).routeInformationProvider.value.uri.path;

        // Search tab: go back to whichever tab was active before.
        if (path == '/search') {
          switch (_previousTabIndex) {
            case 0:
              context.go('/live');
            case 1:
              context.go('/movies');
            case 2:
              context.go('/series');
          }
          return;
        }
        // Root tab (live/movies/series) — back is disabled.
      },
      child: widget.child,
    );

    if (PlatformHelper.isTV(context)) {
      return Scaffold(
        body: Row(
          children: [
            _TvNavRail(onBeforeNavigate: onBeforeNavigate),
            Expanded(child: navigator),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigator,
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
  const _TvNavRail({required this.onBeforeNavigate});

  final void Function(int currentIndex, int newIndex) onBeforeNavigate;

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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TvFocusable(
                  autofocus: i == index,
                  onTap: () {
                    onBeforeNavigate(index, i);
                    context.go(_kNavDestinations[i].path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _kNavDestinations[i].icon,
                          size: 28,
                          color: i == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _kNavDestinations[i].label,
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: i == index
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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

