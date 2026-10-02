import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/features/settings/refresh_all.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Edit a playlist: its name, and — when a provider moves server or changes
/// your login — the server address, username, password or playlist link.
///
/// The stored password is never shown: leaving the field empty keeps it.
/// New connection details are checked with the provider before anything is
/// saved, then the channels, movies and series are refreshed so every
/// stream uses them.
class EditPlaylistScreen extends ConsumerStatefulWidget {
  const EditPlaylistScreen({super.key, required this.source});

  final Source source;

  @override
  ConsumerState<EditPlaylistScreen> createState() =>
      _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends ConsumerState<EditPlaylistScreen> {
  late final _name = TextEditingController(text: widget.source.nickname);
  late final _host = TextEditingController(text: widget.source.xtreamHost);
  late final _user = TextEditingController(text: widget.source.xtreamUsername);
  final _pass = TextEditingController();
  late final _url = TextEditingController(
      text: _isFile ? null : widget.source.m3uUrl);
  late final _guide = TextEditingController(text: _initialGuide());

  bool _showPassword = false;
  String? _status;
  String? _error;

  bool get _isXtream => widget.source.type == SourceType.xtream;
  bool get _isFile => LocalPlaylists.isLocal(widget.source.m3uUrl);
  bool get _saving => _status != null;

  // The automatic Xtream guide link has the login inside it — show it as
  // "automatic" (empty) rather than as a link.
  String? _initialGuide() {
    final s = widget.source;
    if (s.epgUrl == null || s.epgUrl!.isEmpty) return null;
    return s.epgUrl == SourceManager.automaticGuideUrl(s) ? null : s.epgUrl;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _user, _pass, _url, _guide]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _error = null;
      _status = 'Checking your details…';
    });
    final manager = ref.read(sourceManagerProvider);
    try {
      final save = manager.updateSource(
        widget.source,
        nickname: _name.text,
        m3uUrl: _url.text,
        xtreamHost: _host.text,
        xtreamUsername: _user.text,
        xtreamPassword: _pass.text,
        epgUrl: _guide.text,
      );
      // Validation is quick; once it passes the refresh can take a while.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _saving) {
          setState(() => _status = 'Saved. Updating channels and movies…');
        }
      });
      final result = await save;
      ref.invalidate(allSourcesProvider);
      final name = _name.text.trim().isEmpty
          ? widget.source.nickname
          : _name.text.trim();
      messenger.showSnackBar(SnackBar(
        content: Text(result == null
            ? '"$name" saved.'
            : refreshSummary(RefreshScope.everything, [result]) ==
                    'Everything is up to date.'
                ? '"$name" saved and updated.'
                : '"$name" saved. '
                    '${refreshSummary(RefreshScope.everything, [result])}'),
      ));
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = friendlySourceErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Leaving mid-save is fine — it finishes in the background — but
      // not while the details are still being checked (nothing saved yet).
      canPop: _status != 'Checking your details…',
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Playlist')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _Field(
              label: 'Name',
              ctrl: _name,
              hint: widget.source.nickname,
              enabled: !_saving,
            ),
            if (_isXtream) ...[
              _Field(
                label: 'Server address',
                ctrl: _host,
                hint: 'http://example.com:8080',
                type: TextInputType.url,
                enabled: !_saving,
              ),
              _Field(
                label: 'Username',
                ctrl: _user,
                hint: 'Username',
                enabled: !_saving,
              ),
              _Field(
                label: 'Password',
                ctrl: _pass,
                hint: 'Leave empty to keep the current password',
                obscure: !_showPassword,
                enabled: !_saving,
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ] else if (!_isFile)
              _Field(
                label: 'Playlist link',
                ctrl: _url,
                hint: 'https://example.com/playlist.m3u',
                type: TextInputType.url,
                enabled: !_saving,
              ),
            _Field(
              label: 'TV guide address (optional)',
              ctrl: _guide,
              hint: _isXtream
                  ? 'Automatic — from your provider'
                  : 'Automatic — from the playlist',
              type: TextInputType.url,
              enabled: !_saving,
            ),
            if (_isFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'This playlist is a file on your device. To use a '
                  'different file, add it as a new playlist.',
                  style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your login is stored encrypted on this device.',
                      style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(_error!,
                    style: theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 24),
            if (_saving)
              Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(_status!, style: theme.textTheme.bodyLarge)),
                ],
              )
            else
              TvActivatable(
                // TV: start on Save (Up reaches the fields) — focusing a
                // field would pop the on-screen keyboard straight away.
                autofocus: PlatformHelper.isTV(context),
                onTap: _save,
                borderRadius: BorderRadius.circular(28),
                builder: (onTap) => FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Save'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.type,
    this.obscure = false,
    this.suffix,
    this.enabled = true,
  });

  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelLarge!
                  .copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: type,
            obscureText: obscure,
            enabled: enabled,
            autocorrect: false,
            enableSuggestions: !obscure && type != TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}
