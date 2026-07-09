import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _tooltipController = InfoTooltipController();

  // M3U fields
  final _m3uUrlController = TextEditingController();

  // Xtream fields
  final _xtreamHostController = TextEditingController();
  final _xtreamUsernameController = TextEditingController();
  final _xtreamPasswordController = TextEditingController();
  bool _xtreamPasswordVisible = false;

  // Shared fields
  final _nicknameController = TextEditingController();
  final _epgUrlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _progressStep;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _epgUrlController.clear();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tooltipController.dispose();
    _m3uUrlController.dispose();
    _xtreamHostController.dispose();
    _xtreamUsernameController.dispose();
    _xtreamPasswordController.dispose();
    _nicknameController.dispose();
    _epgUrlController.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    setState(() {
      _isLoading = true;
      _progressStep = null;
      _errorMessage = null;
    });

    final manager = ref.read(sourceManagerProvider);
    final nickname = _nicknameController.text.trim();
    final epgUrl =
        _epgUrlController.text.trim().isEmpty ? null : _epgUrlController.text.trim();

    void onProgress(String step) {
      if (mounted) setState(() => _progressStep = step);
    }

    try {
      if (_tabController.index == 0) {
        final url = _m3uUrlController.text.trim();
        if (url.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter the M3U URL.';
            _isLoading = false;
          });
          return;
        }
        if (nickname.isEmpty) {
          setState(() {
            _errorMessage = 'Please give this source a nickname.';
            _isLoading = false;
          });
          return;
        }
        await manager.addSource(
          nickname: nickname,
          type: SourceType.m3u,
          m3uUrl: url,
          epgUrl: epgUrl,
          onProgress: onProgress,
        );
      } else {
        final host = _xtreamHostController.text.trim();
        final user = _xtreamUsernameController.text.trim();
        final pass = _xtreamPasswordController.text.trim();
        if (host.isEmpty || user.isEmpty || pass.isEmpty) {
          setState(() {
            _errorMessage =
                'Please fill in the server address, username, and password.';
            _isLoading = false;
          });
          return;
        }
        if (nickname.isEmpty) {
          setState(() {
            _errorMessage = 'Please give this source a nickname.';
            _isLoading = false;
          });
          return;
        }
        await manager.addSource(
          nickname: nickname,
          type: SourceType.xtream,
          xtreamHost: host,
          xtreamUsername: user,
          xtreamPassword: pass,
          epgUrl: epgUrl,
          onProgress: onProgress,
        );
      }

      if (!mounted) return;
      // Invalidate the cached sources list so the router redirect sees the
      // newly-added source and doesn't loop us back to /onboarding.
      ref.invalidate(allSourcesProvider);
      context.go('/live');
    } catch (e) {
      if (!mounted) return;
      final userMessage = friendlySourceErrorMessage(e);
      setState(() {
        _errorMessage = userMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoTooltipScope(
      controller: _tooltipController,
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: _isLoading ? null : _addSource,
              child: const Text('Add Playlist'),
            ),
          ),
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: IgnorePointer(
                  ignoring: _isLoading,
                  child: AnimatedOpacity(
                    opacity: _isLoading ? 0.38 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add a Playlist',
                                  style: theme.textTheme.headlineMedium),
                              const SizedBox(height: 8),
                              Text(
                                'A playlist is where your channels come from. '
                                'Your provider will give you either an M3U link or Xtream credentials.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              InfoTooltip(
                                id: 'add_source_nickname',
                                title: 'Nickname',
                                body:
                                    'A friendly name for this source so you can tell it apart from others. '
                                    'For example: "Home Server" or "Work VPN".',
                                child: Text('Nickname',
                                    style: theme.textTheme.bodyMedium),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nicknameController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Home Server',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'M3U URL'),
                            Tab(text: 'Xtream'),
                          ],
                        ),
                        SizedBox(
                          height: 420,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _M3uTab(urlController: _m3uUrlController),
                              _XtreamTab(
                                hostController: _xtreamHostController,
                                usernameController: _xtreamUsernameController,
                                passwordController: _xtreamPasswordController,
                                passwordVisible: _xtreamPasswordVisible,
                                onTogglePassword: () => setState(() =>
                                    _xtreamPasswordVisible =
                                        !_xtreamPasswordVisible),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Xtream has built-in EPG; only show external EPG for M3U.
                      if (_tabController.index == 0) ...[
                        const SizedBox(height: 8),
                        InfoTooltip(
                          id: "add_source_epg",
                          title: "TV Guide URL (optional)",
                          body: "A link to an XMLTV file that provides programme schedules "
                              "for your channels. Your provider may supply this separately. "
                              "Leave it blank if you’re not sure — it can be added later.",
                          tip: "Many M3U playlists already include a guide URL. "
                              "OpenIPTV will detect it automatically.",
                          child: Text("TV Guide URL (optional)",
                              style: theme.textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _epgUrlController,
                          decoration: const InputDecoration(
                            hintText: "https://example.com/epg.xml",
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 8),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: theme.colorScheme.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: theme.textTheme.bodySmall!.copyWith(
                                      color: theme.colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_isLoading) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _progressStep ?? 'Starting…',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
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

class _M3uTab extends StatelessWidget {
  const _M3uTab({required this.urlController});

  final TextEditingController urlController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTooltip(
            id: 'add_source_m3u_url',
            title: 'M3U URL',
            body:
                'A direct link to an M3U or M3U+ playlist file. '
                'Your IPTV provider will give you this link. '
                'It usually ends in .m3u or .m3u8.',
            tip: 'Paste the full URL including https://',
            child: Text('M3U URL', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'https://example.com/playlist.m3u',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Text(
            'Paste the M3U link your provider gave you. '
            'If you have a username and password instead, switch to the Xtream tab.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _XtreamTab extends StatelessWidget {
  const _XtreamTab({
    required this.hostController,
    required this.usernameController,
    required this.passwordController,
    required this.passwordVisible,
    required this.onTogglePassword,
  });

  final TextEditingController hostController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTooltip(
            id: 'add_source_xtream_host',
            title: 'Server Address',
            body:
                'The base URL of your Xtream-compatible server. '
                'This is usually a domain name or IP address, '
                'with or without a port number.',
            tip: 'Example: http://your-provider.com:8080',
            child:
                Text('Server Address', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hostController,
            decoration: const InputDecoration(
              hintText: 'http://your-provider.com:8080',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          InfoTooltip(
            id: 'add_source_xtream_user',
            title: 'Username',
            body:
                'The username given to you by your IPTV provider. '
                'This is different from any email address you used to sign up.',
            child: Text('Username', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(hintText: 'your_username'),
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          InfoTooltip(
            id: 'add_source_xtream_pass',
            title: 'Password',
            body:
                'The password given to you by your IPTV provider. '
                'Your provider’s password is separate from your OpenIPTV profile PIN.',
            child: Text('Password', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(
              hintText: 'your_password',
              suffixIcon: IconButton(
                icon: Icon(
                  passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            obscureText: !passwordVisible,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}
