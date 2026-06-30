import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/channel_list_screen.dart';
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
import 'package:open_iptv/features/settings/profile_picker_screen.dart';
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
  bool _splashDone = false;
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

    // Initialise theme + sort state from persisted preferences.
    ref.read(themeModeProvider.notifier).state =
        modeFromString(prefs.themeMode);
    ref.read(accentColorProvider.notifier).state =
        AppTheme.accentFromHex(prefs.accentColor);
    ref.read(contentSortProvider.notifier).state = prefs.contentSort;
    ref.read(viewModeLiveProvider.notifier).state = prefs.viewModeLive;
    ref.read(viewModeMoviesProvider.notifier).state = prefs.viewModeMovies;
    ref.read(viewModeSeriesProvider.notifier).state = prefs.viewModeSeries;
    ref.read(activeSourceIdProvider.notifier).state = prefs.activeSourceId;

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
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    if (!_dbReady || !_splashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _SplashView(
          onDone: () {
            if (mounted) setState(() => _splashDone = true);
          },
        ),
      );
    }

    // Show profile picker before mounting the router when multiple
    // profiles exist and the user hasn't selected one this session.
    if (_needsProfilePick && !_profilePicked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accent),
        darkTheme: AppTheme.dark(accent),
        themeMode: themeMode,
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
        theme: AppTheme.light(accent),
        darkTheme: AppTheme.dark(accent),
        themeMode: themeMode,
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
  // Remembers which tab was active before the user navigated to Search,
  // so the back button can return there instead of showing the exit dialog.
  int _previousTabIndex = 0;
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    // BackButtonListener fires BEFORE go_router's popRoute(), so we can
    // intercept the back button when at a root tab and show the exit dialog.
    // PopScope alone doesn't work here: canPop=false causes go_router to see
    // Navigator.canPop()=false and call SystemNavigator.pop() directly,
    // skipping onPopInvoked entirely.
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!mounted) return false;

        // If the root navigator has anything stacked above the shell (player,
        // settings, sub-pages), let the navigator pop it — don't interfere.
        // This is reliable where path-reading was not: path reflects the shell's
        // underlying tab even when settings/player are pushed on top.
        if (Navigator.of(context, rootNavigator: true).canPop()) return false;

        // Read the real current URI (GoRouterState at shell level is unreliable).
        final path =
            GoRouter.of(context).routeInformationProvider.value.uri.path;

        // Search tab: return to whichever tab was active before Search.
        if (path == '/search') {
          switch (_previousTabIndex) {
            case 0:
              context.go('/live');
            case 1:
              context.go('/movies');
            case 2:
              context.go('/series');
          }
          return true;
        }

        // Root tab — require double-tap to exit (Reddit-style).
        final now = DateTime.now();
        final last = _lastBackPress;
        if (last == null || now.difference(last) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return true;
        }
        return false;
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: _BottomNav(
          onBeforeNavigate: (currentIndex, newIndex) {
            if (newIndex == 3 && currentIndex != 3) {
              setState(() => _previousTabIndex = currentIndex);
            }
          },
        ),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.onBeforeNavigate});

  final void Function(int currentIndex, int newIndex) onBeforeNavigate;

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
        onBeforeNavigate(index, i);
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

extension ProfileGear on BuildContext {
  void openSettings() => push('/settings');
}

// ---------------------------------------------------------------------------
// Animated splash screen
// ---------------------------------------------------------------------------

class _SplashView extends StatefulWidget {
  const _SplashView({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _glowCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _logoScale = Tween(begin: 0.30, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoCtrl, curve: const Interval(0.0, 0.35, curve: Curves.easeIn)),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textCtrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)),
    );
    _textSlide = Tween(begin: const Offset(0, 0.55), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _taglineOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textCtrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOut)),
    );
    _glowPulse = Tween(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _logoCtrl.forward().then((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _textCtrl.forward();
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07070F), Color(0xFF12122A)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 5),
            // Logo with animated glow halo
            AnimatedBuilder(
              animation: Listenable.merge([_logoCtrl, _glowCtrl]),
              builder: (_, child) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer soft glow
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color.fromRGBO(91, 79, 255,
                                    _glowPulse.value * 0.28),
                                Color.fromRGBO(58, 46, 204,
                                    _glowPulse.value * 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Inner tighter glow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color.fromRGBO(123, 111, 255,
                                    _glowPulse.value * 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        child!,
                      ],
                    ),
                  ),
                ),
              ),
              child: Image.asset(
                'assets/images/app_icon_dark.png',
                width: 110,
                height: 110,
              ),
            ),
            const SizedBox(height: 44),
            // App name + tagline
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => FractionalTranslation(
                translation: _textSlide.value,
                child: Column(
                  children: [
                    Opacity(
                      opacity: _textOpacity.value,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFC0B8FF)],
                        ).createShader(bounds),
                        child: const Text(
                          'OpenIPTV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: const Text(
                        'Open Source. Ad Free. Cross Platform.',
                        style: TextStyle(
                          color: Color(0xFF6868A0),
                          fontSize: 13,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 7),
          ],
        ),
      ),
    );
  }
}
