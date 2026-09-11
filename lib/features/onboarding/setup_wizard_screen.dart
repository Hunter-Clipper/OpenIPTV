import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/widgets/pin_keypad.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Shared theme constants
//
// These alias the app's real palette (AppTheme) rather than declaring an
// unrelated one, so the first screen a new user sees already matches every
// screen after it. _kMuted/_kBgDark/_kCardBg etc. are kept as short local
// names purely to avoid a much larger diff across this file.
// ---------------------------------------------------------------------------

const _kBgDark = AppTheme.backgroundColor;
const _kBgMid = AppTheme.surfaceColor;
const _kMuted = AppTheme.mutedTextColor;
const _kCardBg = AppTheme.surfaceVariantColor;
const _kCardBorder = AppTheme.outlineColor;

/// A lighter tint of [color], used for the wizard's gradient accents.
Color _lighten(Color color, [double amount = 0.3]) =>
    Color.lerp(color, Colors.white, amount)!;

// ---------------------------------------------------------------------------
// SetupWizardScreen
// ---------------------------------------------------------------------------

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();

  // Profile state
  final _nameCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  // Each explicitly requestFocus()'d from _goToPage at the moment the
  // wizard actually navigates to that page — see _nameFocusNode's original
  // comment and TvFocusable.focusNode's doc for why plain `autofocus: true`
  // doesn't work reliably on this PageView (every page is built up front,
  // so autofocus fires far too early and loses the initial-focus race to
  // whichever page happened to build first).
  final _pin1FocusNode = FocusNode();
  final _xtreamCardFocusNode = FocusNode();
  final _nicknameFocusNode = FocusNode();
  String _avatarEmoji = '🧑';
  Color _accentColor = const Color(0xFF0A84FF); // default blue
  String _pin = '';
  bool _wantsPin = false;

  // Source state
  SourceType _playlistType = SourceType.xtream;
  final _nicknameCtrl = TextEditingController();
  final _xtreamHostCtrl = TextEditingController();
  final _xtreamUserCtrl = TextEditingController();
  final _xtreamPassCtrl = TextEditingController();
  bool _passVisible = false;
  final _m3uUrlCtrl = TextEditingController();
  final _epgUrlCtrl = TextEditingController();

  // Loading / all-set state
  bool _isLoading = false;
  String? _errorMessage;
  String _progressMessage = 'Connecting…';

  // All-set animations
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkScale;
  late final AnimationController _sparkleCtrl;
  late final Animation<double> _sparkleAngle;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _sparkleAngle = Tween(begin: 0.0, end: 2 * pi).animate(_sparkleCtrl);

    // Autofocus on a TextField at page-transition time (rather than the
    // widget's own `autofocus: true`) is notoriously unreliable at getting
    // Android's soft keyboard to actually show — the IME often only shows
    // for a focus change it can tie to a genuine user gesture. Nudging it
    // explicitly here (also re-armed in the focus listener below) is the
    // standard workaround.
    _nameFocusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      // TextField swallows arrow keys for cursor movement, which — with
      // nothing to move to in a single-line field — otherwise traps D-pad
      // focus inside it with no way out (reported directly by a user
      // testing on a real Android TV remote).
      final key = event.logicalKey;
      final ctx = node.context;
      if (ctx == null) return KeyEventResult.ignored;
      if (key == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(ctx).nextFocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(ctx).previousFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _checkCtrl.dispose();
    _sparkleCtrl.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _pin1FocusNode.dispose();
    _xtreamCardFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _nicknameCtrl.dispose();
    _xtreamHostCtrl.dispose();
    _xtreamUserCtrl.dispose();
    _xtreamPassCtrl.dispose();
    _m3uUrlCtrl.dispose();
    _epgUrlCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
    // PageView keeps every page built at once, so each page's own controls
    // exist (and could otherwise steal focus) well before that page is
    // actually shown — only request focus once we're actually navigating
    // to it, on whichever control should be the D-pad starting point there.
    final focusNode = switch (page) {
      1 => _nameFocusNode,
      2 => _pin1FocusNode,
      3 => _xtreamCardFocusNode,
      4 => _nicknameFocusNode,
      _ => null,
    };
    if (focusNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusNode.requestFocus();
      });
    }
  }

  Future<void> _submitSource() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progressMessage = 'Connecting…';
    });
    _goToPage(5);

    try {
      final manager = ref.read(sourceManagerProvider);
      final nickname = _nicknameCtrl.text.trim();
      final epgUrl = _epgUrlCtrl.text.trim().isEmpty
          ? null
          : _epgUrlCtrl.text.trim();

      void onProgress(String msg) {
        if (mounted) setState(() => _progressMessage = msg);
      }

      // Add the playlist first — it's the step most likely to fail (bad
      // credentials, bad URL, network issues). Only create the profile once
      // it succeeds, so a failed attempt leaves nothing behind to retry into.
      if (_playlistType == SourceType.m3u) {
        await manager.addSource(
          nickname: nickname,
          type: SourceType.m3u,
          m3uUrl: _m3uUrlCtrl.text.trim(),
          epgUrl: epgUrl,
          onProgress: onProgress,
        );
      } else {
        await manager.addSource(
          nickname: nickname,
          type: SourceType.xtream,
          xtreamHost: _xtreamHostCtrl.text.trim(),
          xtreamUsername: _xtreamUserCtrl.text.trim(),
          xtreamPassword: _xtreamPassCtrl.text.trim(),
          epgUrl: epgUrl,
          onProgress: onProgress,
        );
      }

      if (!mounted) return;

      final prefs = await ref.read(appPreferencesProvider.future);
      final db = ref.read(appDatabaseProvider);
      final profileSvc = ProfileService(db: db, prefs: prefs);
      await profileSvc.createProfile(
        name: _nameCtrl.text.trim(),
        avatarEmoji: _avatarEmoji,
        pin: _wantsPin && _pin.length == 4 ? _pin : null,
        isAdmin: true,
      );

      // Persist and apply the chosen accent colour immediately.
      await prefs.setAccentColor(AppTheme.hexFromAccent(_accentColor));
      ref.read(accentColorProvider.notifier).state = _accentColor;

      if (!mounted) return;
      ref.invalidate(allSourcesProvider);

      _goToPage(6);
      unawaited(_checkCtrl.forward());
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.go('/live');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = friendlySourceErrorMessage(e);
      });
      _goToPage(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgDark,
      resizeToAvoidBottomInset: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onStart: () => _goToPage(1)),
          _NamePage(
            nameCtrl: _nameCtrl,
            nameFocusNode: _nameFocusNode,
            selectedAvatar: _avatarEmoji,
            onAvatarSelected: (e) => setState(() => _avatarEmoji = e),
            selectedColor: _accentColor,
            onColorSelected: (c) => setState(() => _accentColor = c),
            onContinue: () {
              if (_nameCtrl.text.trim().isEmpty) return;
              _goToPage(2);
            },
          ),
          _PinPage(
            accentColor: _accentColor,
            firstDigitFocusNode: _pin1FocusNode,
            onSkip: () {
              setState(() {
                _wantsPin = false;
                _pin = '';
              });
              _goToPage(3);
            },
            onPinSet: (pin) {
              setState(() {
                _wantsPin = true;
                _pin = pin;
              });
              _goToPage(3);
            },
          ),
          _PlaylistTypePage(
            accentColor: _accentColor,
            firstCardFocusNode: _xtreamCardFocusNode,
            onSelected: (type) {
              setState(() => _playlistType = type);
              _goToPage(4);
            },
          ),
          _CredentialsPage(
            accentColor: _accentColor,
            playlistType: _playlistType,
            nicknameCtrl: _nicknameCtrl,
            nicknameFocusNode: _nicknameFocusNode,
            xtreamHostCtrl: _xtreamHostCtrl,
            xtreamUserCtrl: _xtreamUserCtrl,
            xtreamPassCtrl: _xtreamPassCtrl,
            passVisible: _passVisible,
            onTogglePass: () => setState(() => _passVisible = !_passVisible),
            m3uUrlCtrl: _m3uUrlCtrl,
            epgUrlCtrl: _epgUrlCtrl,
            errorMessage: _errorMessage,
            onBack: () => _goToPage(3),
            onSubmit: _isLoading ? null : _submitSource,
          ),
          _LoadingPage(message: _progressMessage, accentColor: _accentColor),
          _AllSetPage(
            name: _nameCtrl.text.trim(),
            accentColor: _accentColor,
            checkScale: _checkScale,
            sparkleAngle: _sparkleAngle,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 0 — Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatefulWidget {
  const _WelcomePage({required this.onStart});
  final VoidCallback onStart;

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _glowPulse;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _glowPulse = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _slide = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
    _btnScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WizardBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: Listenable.merge([_fadeCtrl, _glowCtrl]),
                builder: (_, child) => Opacity(
                  opacity: _fade.value,
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color.fromRGBO(91, 79, 255, _glowPulse.value * 0.3),
                                Color.fromRGBO(58, 46, 204, _glowPulse.value * 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color.fromRGBO(123, 111, 255, _glowPulse.value * 0.2),
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
                child: Image.asset(
                  'assets/images/app_icon_dark.png',
                  width: 90,
                  height: 90,
                ),
              ),
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _fadeCtrl,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: Opacity(
                    opacity: _fade.value,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFC0B8FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Welcome to\nOpenIPTV',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Let's get you set up.\nIt only takes a minute.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _kMuted,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _fadeCtrl,
                builder: (_, child) =>
                    Transform.scale(scale: _btnScale.value, child: child),
                child: _GradientButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward,
                  accentColor: AppTheme.accentSwatches.first.color,
                  onTap: widget.onStart,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — Name + Avatar
// ---------------------------------------------------------------------------

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.nameCtrl,
    required this.nameFocusNode,
    required this.selectedAvatar,
    required this.onAvatarSelected,
    required this.selectedColor,
    required this.onColorSelected,
    required this.onContinue,
  });

  final TextEditingController nameCtrl;
  final FocusNode nameFocusNode;
  final String selectedAvatar;
  final ValueChanged<String> onAvatarSelected;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onContinue;

  static const _avatars = [
    '👨', '👩', '🧒', '👦', '👧', '🧑', '👴', '👵',
    '🎭', '🌟', '🎮', '🎬', '📺', '🎵', '🏠', '⚽',
    '🎸', '🐱', '🐶', '🦄',
  ];

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformHelper.isTV(context);
    // A modest bump, not a multiplier applied blindly — Android TV renders
    // at a much higher density than a phone (this hardware reports 1920x1080
    // physical but only ~960x540 *logical* px), so the actual usable height
    // on TV is often SHORTER than a phone's, not taller. The scrollable
    // wrapper below is the real safety net; this is just breathing room.
    double v(double base) => isTV ? base * 1.15 : base;

    return _WizardBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 28, vertical: isTV ? 16 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              SizedBox(height: v(24)),
              _StepIndicator(current: 0, total: 4, accentColor: selectedColor),
              SizedBox(height: v(36)),
              const Text(
                "What's your name?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: v(8)),
              const Text(
                'All information stays on your device.\nOpenIPTV never collects personal data.',
                style: TextStyle(color: _kMuted, fontSize: 14, height: 1.5),
              ),
              SizedBox(height: v(32)),
              TextField(
                controller: nameCtrl,
                focusNode: nameFocusNode,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onContinue(),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: const TextStyle(color: _kMuted),
                  filled: true,
                  fillColor: _kCardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: selectedColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
              ),
              SizedBox(height: v(32)),
              const Text(
                'Pick an avatar',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: v(12)),
              SizedBox(
                height: 62,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatars.length,
                  itemBuilder: (context, i) {
                    final emoji = _avatars[i];
                    final selected = emoji == selectedAvatar;
                    return TvFocusable(
                      borderRadius: BorderRadius.circular(14),
                      ensureVisibleOnFocus: true,
                      onTap: () => onAvatarSelected(emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: selected
                              ? selectedColor.withValues(alpha: 0.2)
                              : _kCardBg,
                          border: Border.all(
                            color: selected ? selectedColor : _kCardBorder,
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: v(28)),
              const Text(
                'Accent Color',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: v(12)),
              Row(
                children: AppTheme.accentSwatches.map((s) {
                  final sel = s.color == selectedColor;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: TvFocusable(
                      borderRadius: BorderRadius.circular(19),
                      onTap: () => onColorSelected(s.color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: s.color.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
                    ],
                  ),
                ),
              ),
              // Continue is a sibling of the scrollable content above, not a
              // child inside it — always visible and reachable regardless of
              // how tall the content above ends up (scrolls instead of
              // pushing this off-screen, unlike the old Spacer-based layout).
              SizedBox(height: v(16)),
              _GradientButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                accentColor: selectedColor,
                onTap: onContinue,
              ),
              SizedBox(height: v(20)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — PIN (optional)
// ---------------------------------------------------------------------------

class _PinPage extends StatefulWidget {
  const _PinPage({
    required this.accentColor,
    required this.onSkip,
    required this.onPinSet,
    required this.firstDigitFocusNode,
  });
  final Color accentColor;
  final VoidCallback onSkip;
  final ValueChanged<String> onPinSet;
  final FocusNode firstDigitFocusNode;

  @override
  State<_PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<_PinPage> {
  String _digits = '';

  void _onDigit(String d) {
    if (_digits.length < 4) setState(() => _digits += d);
  }

  void _onBackspace() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformHelper.isTV(context);
    // See _NamePage — a modest bump only, TV's usable height can be
    // shorter than a phone's, not taller. The Expanded/SingleChildScrollView
    // below is the real safety net against overflow.
    double v(double base) => isTV ? base * 1.15 : base;

    return _WizardBackground(
      child: SafeArea(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 28, vertical: isTV ? 16 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: v(24)),
                      _StepIndicator(
                          current: 1, total: 4, accentColor: widget.accentColor),
                      SizedBox(height: v(36)),
                      const Text(
                        'Secure your account',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: v(8)),
                      const Text(
                        'Set a 4-digit PIN to protect this admin account.\nYou can skip this and add one later in Settings.',
                        style: TextStyle(
                            color: _kMuted, fontSize: 14, height: 1.5),
                      ),
                      SizedBox(height: v(40)),
                      Center(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context)
                                .colorScheme
                                .copyWith(primary: widget.accentColor),
                          ),
                          child: PinKeypad(
                            pin: _digits,
                            onDigit: _onDigit,
                            onBackspace: _onBackspace,
                            firstDigitFocusNode: widget.firstDigitFocusNode,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: v(16)),
              _GradientButton(
                label: 'Set PIN',
                icon: Icons.lock,
                accentColor: widget.accentColor,
                onTap: _digits.length == 4
                    ? () => widget.onPinSet(_digits)
                    : null,
              ),
              SizedBox(height: v(12)),
              Center(
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: _kMuted, fontSize: 15),
                  ),
                ),
              ),
              SizedBox(height: v(16)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — Playlist type selector
// ---------------------------------------------------------------------------

class _PlaylistTypePage extends StatelessWidget {
  const _PlaylistTypePage({
    required this.accentColor,
    required this.onSelected,
    required this.firstCardFocusNode,
  });
  final Color accentColor;
  final ValueChanged<SourceType> onSelected;
  final FocusNode firstCardFocusNode;

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformHelper.isTV(context);
    // See _NamePage — a modest bump only; the SingleChildScrollView below
    // is what actually protects against overflow on TV's shorter viewport.
    double v(double base) => isTV ? base * 1.15 : base;

    return _WizardBackground(
      child: SafeArea(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 28, vertical: isTV ? 16 : 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: v(24)),
                _StepIndicator(current: 2, total: 4, accentColor: accentColor),
                SizedBox(height: v(36)),
                const Text(
                  'What kind of playlist\ndo you have?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: v(8)),
                const Text(
                  "Not sure? Ask your IPTV provider — they'll know!",
                  style: TextStyle(color: _kMuted, fontSize: 14),
                ),
                SizedBox(height: v(40)),
                _PlaylistTypeCard(
                  icon: '📡',
                  title: 'Xtream Codes',
                  description:
                      'Login with a server address, username, and password.',
                  gradient: const [Color(0xFF3A2ECC), Color(0xFF5B4FFF)],
                  onTap: () => onSelected(SourceType.xtream),
                  focusNode: firstCardFocusNode,
                ),
                SizedBox(height: v(16)),
                _PlaylistTypeCard(
                  icon: '📋',
                  title: 'M3U Playlist',
                  description:
                      'Load from a direct playlist URL (ending in .m3u or .m3u8).',
                  gradient: const [Color(0xFF1A2E6A), Color(0xFF2A4FBF)],
                  onTap: () => onSelected(SourceType.m3u),
                ),
                SizedBox(height: v(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistTypeCard extends StatefulWidget {
  const _PlaylistTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
    this.focusNode,
  });

  final String icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;
  // See TvFocusable.focusNode's doc — plain autofocus isn't reliable here
  // since this card lives inside a wizard PageView page that's built up
  // front, long before it's actually shown.
  final FocusNode? focusNode;

  @override
  State<_PlaylistTypeCard> createState() => _PlaylistTypeCardState();
}

class _PlaylistTypeCardState extends State<_PlaylistTypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      wrapsGesture: false,
      ensureVisibleOnFocus: true,
      focusNode: widget.focusNode,
      borderRadius: BorderRadius.circular(20),
      onTap: widget.onTap,
      child: GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) =>
            Transform.scale(scale: _pressCtrl.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.last.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 38)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — Credentials form
// ---------------------------------------------------------------------------

class _CredentialsPage extends StatelessWidget {
  const _CredentialsPage({
    required this.accentColor,
    required this.playlistType,
    required this.nicknameCtrl,
    required this.xtreamHostCtrl,
    required this.xtreamUserCtrl,
    required this.xtreamPassCtrl,
    required this.passVisible,
    required this.onTogglePass,
    required this.m3uUrlCtrl,
    required this.epgUrlCtrl,
    required this.errorMessage,
    required this.onBack,
    required this.onSubmit,
    required this.nicknameFocusNode,
  });

  final Color accentColor;
  final SourceType playlistType;
  final TextEditingController nicknameCtrl;
  final FocusNode nicknameFocusNode;
  final TextEditingController xtreamHostCtrl;
  final TextEditingController xtreamUserCtrl;
  final TextEditingController xtreamPassCtrl;
  final bool passVisible;
  final VoidCallback onTogglePass;
  final TextEditingController m3uUrlCtrl;
  final TextEditingController epgUrlCtrl;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isXtream = playlistType == SourceType.xtream;
    return _WizardBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70),
                        tooltip: 'Back',
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 4),
                      _StepIndicator(
                          current: 3, total: 4, accentColor: accentColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isXtream ? 'Xtream Credentials' : 'M3U Playlist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isXtream
                              ? 'Enter the login details from your provider.'
                              : 'Paste the playlist link your provider gave you.',
                          style:
                              const TextStyle(color: _kMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WizardField(
                      label: 'Nickname',
                      ctrl: nicknameCtrl,
                      hint: 'e.g. Home Server',
                      accentColor: accentColor,
                      focusNode: nicknameFocusNode,
                    ),
                    const SizedBox(height: 16),
                    if (isXtream) ...[
                      _WizardField(
                        label: 'Server Address',
                        ctrl: xtreamHostCtrl,
                        hint: 'http://your-provider.com:8080',
                        type: TextInputType.url,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 16),
                      _WizardField(
                        label: 'Username',
                        ctrl: xtreamUserCtrl,
                        hint: 'your_username',
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 16),
                      _WizardField(
                        label: 'Password',
                        ctrl: xtreamPassCtrl,
                        hint: 'your_password',
                        obscure: !passVisible,
                        accentColor: accentColor,
                        suffix: IconButton(
                          icon: Icon(
                            passVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: _kMuted,
                          ),
                          tooltip: passVisible ? 'Hide password' : 'Show password',
                          onPressed: onTogglePass,
                        ),
                      ),
                    ] else ...[
                      _WizardField(
                        label: 'M3U URL',
                        ctrl: m3uUrlCtrl,
                        hint: 'https://example.com/playlist.m3u',
                        type: TextInputType.url,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 16),
                      _WizardField(
                        label: 'TV Guide URL (optional)',
                        ctrl: epgUrlCtrl,
                        hint: 'https://example.com/epg.xml',
                        type: TextInputType.url,
                        accentColor: accentColor,
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                    color: theme.colorScheme.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _GradientButton(
                      label: 'Load My Playlist',
                      icon: Icons.download,
                      accentColor: accentColor,
                      onTap: onSubmit,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardField extends StatelessWidget {
  const _WizardField({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.accentColor,
    this.type,
    this.obscure = false,
    this.suffix,
    this.focusNode,
  });

  final String label;
  final TextEditingController ctrl;
  final String hint;
  final Color accentColor;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  // See TvFocusable.focusNode's doc — plain autofocus isn't reliable on a
  // wizard page that's built up front, long before it's actually shown.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: type,
          obscureText: obscure,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kMuted),
            filled: true,
            fillColor: _kCardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kCardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5 — Loading
// ---------------------------------------------------------------------------

class _LoadingPage extends StatefulWidget {
  const _LoadingPage({required this.message, required this.accentColor});
  final String message;
  final Color accentColor;

  @override
  State<_LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<_LoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WizardBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.accentColor
                                  .withValues(alpha: _pulse.value * 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    CircularProgressIndicator(
                      color: widget.accentColor,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Setting up your playlist…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: 0.5 + _pulse.value * 0.5,
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: _kMuted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 6 — All set!
// ---------------------------------------------------------------------------

class _AllSetPage extends StatelessWidget {
  const _AllSetPage({
    required this.name,
    required this.accentColor,
    required this.checkScale,
    required this.sparkleAngle,
  });

  final String name;
  final Color accentColor;
  final Animation<double> checkScale;
  final Animation<double> sparkleAngle;

  @override
  Widget build(BuildContext context) {
    final firstName =
        name.isNotEmpty ? name.trim().split(' ').first : 'there';
    return _WizardBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: AnimatedBuilder(
                  animation: Listenable.merge([checkScale, sparkleAngle]),
                  builder: (_, __) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Orbiting sparkle dots
                        ...List.generate(12, (i) {
                          final angle =
                              sparkleAngle.value + (i * 2 * pi / 12);
                          final radius = i % 2 == 0 ? 80.0 : 72.0;
                          final dx = cos(angle) * radius;
                          final dy = sin(angle) * radius;
                          final size = i % 3 == 0
                              ? 7.0
                              : i % 3 == 1
                                  ? 5.0
                                  : 4.0;
                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i % 3 == 0
                                    ? accentColor
                                    : i % 3 == 1
                                        ? _lighten(accentColor)
                                        : Colors.white
                                            .withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }),
                        // Outer glow
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Checkmark
                        Transform.scale(
                          scale: checkScale.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [accentColor, _lighten(accentColor)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 54,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 44),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFC0B8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  "You're all set, $firstName!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your playlist is ready.\nEnjoy the show.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kMuted, fontSize: 16, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _WizardBackground extends StatelessWidget {
  const _WizardBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // This wizard's pages are all designed at phone width (fixed 28px side
    // padding, buttons/cards that stretch to fill whatever width they're
    // given) — full-bleed on a TV screen stretches everything into an
    // oversized, "mooshed"-looking layout. Capping and centering the width
    // here, in the one shared background wrapper every page uses, fixes all
    // of them at once without touching each page's own layout.
    //
    // Height is deliberately NOT force-fit here — Android TV renders at a
    // much higher density than a phone (this hardware: 1920x1080 physical
    // but only ~960x540 *logical* px, since TV UI is drawn bigger for
    // 10-foot viewing), so the actual usable height on TV can be SHORTER
    // than a phone's, not taller. Each page handles its own vertical
    // overflow (scrolling the middle, pinning the action button) rather
    // than this wrapper guessing at available height.
    Widget wrap(Widget page) {
      if (!PlatformHelper.isTV(context)) return page;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: page,
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgDark, _kBgMid],
        ),
      ),
      child: wrap(child),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.current,
    required this.total,
    required this.accentColor,
  });
  final int current;
  final int total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? accentColor
                : done
                    ? _lighten(accentColor).withValues(alpha: 0.6)
                    : _kCardBorder,
          ),
        );
      }),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return TvFocusable(
      autofocus: enabled,
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [accentColor, _lighten(accentColor)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : _kCardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
