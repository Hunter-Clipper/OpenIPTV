import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/features/live_tv/channel_list_screen.dart';
import 'package:open_iptv/features/movies/movie_detail_screen.dart';
import 'package:open_iptv/features/movies/movies_screen.dart';
import 'package:open_iptv/features/onboarding/add_source_screen.dart';
import 'package:open_iptv/features/player/player_screen.dart';
import 'package:open_iptv/features/search/search_screen.dart';
import 'package:open_iptv/features/series/episode_list_screen.dart';
import 'package:open_iptv/features/series/series_detail_screen.dart';
import 'package:open_iptv/features/series/series_screen.dart';
import 'package:open_iptv/features/settings/backup_screen.dart';
import 'package:open_iptv/features/settings/profile_screen.dart';
import 'package:open_iptv/features/settings/settings_screen.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';

class OpenIPTVApp extends ConsumerStatefulWidget {
  const OpenIPTVApp({super.key});

  @override
  ConsumerState<OpenIPTVApp> createState() => _OpenIPTVAppState();
}

class _OpenIPTVAppState extends ConsumerState<OpenIPTVApp> {
  late final GoRouter _router;
  final _tooltipController = InfoTooltipController();
  bool _dbReady = false;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _openDb();
  }

  // Touch the DB to force LazyDatabase.ensureOpen() + schema migrations to
  // complete before GoRouter is mounted.  The router redirect also queries the
  // DB, and NativeDatabase.createInBackground's background isolate is still
  // running onCreate/onUpgrade at the exact moment the first redirect fires —
  // causing SqliteException(5) "database is locked".  By serialising startup
  // here we guarantee the isolate is idle and the connection is ready.
  //
  // Retries handle the rare case where an OS-level file lock (Android backup
  // service, WAL recovery) outlasts the 5s busy_timeout set in _dbSetup.
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
    if (mounted) setState(() => _dbReady = true);
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
        // DB is guaranteed open before this fires — see _openDb() above.
        final sources = await ref.read(appDatabaseProvider).getAllSources();
        if (sources.isEmpty && !state.fullPath!.startsWith('/onboarding')) {
          return '/onboarding';
        }
        return null;
      },
      routes: [
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
            ),
            GoRoute(
              path: '/movies',
              builder: (_, __) => const MoviesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      MovieDetailScreen(movieId: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/series',
              builder: (_, __) => const SeriesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
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
              ],
            ),
            GoRoute(
              path: '/search',
              builder: (_, __) => const SearchScreen(),
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
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_dbReady) {
      // Show a dark splash while the background DB isolate opens and migrates.
      // The router must not be mounted yet — its redirect queries the DB and
      // would race with migrations if we rendered it here.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.jpg', width: 140, height: 140),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }
    // TODO: wire theme from AppPreferences
    return InfoTooltipScope(
      controller: _tooltipController,
      child: MaterialApp.router(
        title: 'OpenIPTV',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).fullPath ?? '/live';

    int index = 0;
    if (location.startsWith('/live')) index = 0;
    if (location.startsWith('/movies')) index = 1;
    if (location.startsWith('/series')) index = 2;
    if (location.startsWith('/search')) index = 3;

    return BottomNavigationBar(
      currentIndex: index,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/live');
          case 1:
            context.go('/movies');
          case 2:
            context.go('/series');
          case 3:
            context.go('/search');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Live TV'),
        BottomNavigationBarItem(
            icon: Icon(Icons.movie_outlined), label: 'Movies'),
        BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined), label: 'Series'),
        BottomNavigationBarItem(
            icon: Icon(Icons.search), label: 'Search'),
      ],
    );
  }
}

// Expose activeProfile as a convenience for the settings gear icon.
extension ProfileGear on BuildContext {
  void openSettings() => go('/settings');
}
