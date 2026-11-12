import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/features/settings/refresh_all.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

enum _SaveStage { checking, updating }

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
  late String _liveFormat = widget.source.liveFormat;
  _SaveStage? _stage;
  String? _error;

  bool get _isXtream => widget.source.type == SourceType.xtream;
  bool get _isFile => LocalPlaylists.isLocal(widget.source.m3uUrl);
  bool get _saving => _stage != null;

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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _error = null;
      _stage = _SaveStage.checking;
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
        liveFormat: _liveFormat,
      );
      // Validation is quick; once it passes the refresh can take a while.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _saving) {
          setState(() => _stage = _SaveStage.updating);
        }
      });
      final result = await save;
      ref.invalidate(allSourcesProvider);
      final name = _name.text.trim().isEmpty
          ? widget.source.nickname
          : _name.text.trim();
      final summary = result == null
          ? null
          : refreshSummary(l10n, RefreshScope.everything, [result]);
      messenger.showSnackBar(SnackBar(
        content: Text(summary == null
            ? l10n.editPlaylistSaved(name)
            : summary == l10n.refreshAllSummaryEverything
                ? l10n.editPlaylistSavedUpdated(name)
                : l10n.editPlaylistSavedWithSummary(name, summary)),
      ));
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = null;
          _error = friendlySourceErrorMessage(e, AppLocalizations.of(context));
        });
      }
    }
  }

  static List<(String, String, String)> _liveFormats(AppLocalizations l10n) => [
        ('auto', l10n.editPlaylistFormatAutoLabel,
            l10n.editPlaylistFormatAutoDescription),
        ('ts', 'TS', l10n.editPlaylistFormatTsDescription),
        ('hls', 'HLS', l10n.editPlaylistFormatHlsDescription),
      ];

  /// Which kind of link live channels use. Movies and series are unaffected.
  Widget _liveFormatPicker(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.editPlaylistLiveFormat, style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            l10n.editPlaylistLiveFormatNote,
            style: theme.textTheme.bodySmall!
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          for (final (id, label, description) in _liveFormats(l10n))
            TvActivatable(
              onTap: _saving ? null : () => setState(() => _liveFormat = id),
              borderRadius: BorderRadius.circular(12),
              builder: (tap) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  id == _liveFormat
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: id == _liveFormat ? theme.colorScheme.primary : null,
                ),
                title: Text(label),
                subtitle: Text(description, style: theme.textTheme.bodySmall),
                onTap: tap,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // Leaving mid-save is fine — it finishes in the background — but
      // not while the details are still being checked (nothing saved yet).
      canPop: _stage != _SaveStage.checking,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.editPlaylistTitle)),
        body: TvFollowFocus(child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _Field(
              label: l10n.editPlaylistName,
              ctrl: _name,
              hint: widget.source.nickname,
              enabled: !_saving,
              // TV: the remote starts here (OK opens the keyboard).
              autofocus: true,
            ),
            if (_isXtream) ...[
              _Field(
                label: l10n.editPlaylistServerAddress,
                ctrl: _host,
                hint: 'http://example.com:8080',
                type: TextInputType.url,
                enabled: !_saving,
              ),
              _Field(
                label: l10n.editPlaylistUsername,
                ctrl: _user,
                hint: l10n.editPlaylistUsername,
                enabled: !_saving,
              ),
              _Field(
                label: l10n.editPlaylistPassword,
                ctrl: _pass,
                hint: l10n.editPlaylistPasswordHint,
                obscure: !_showPassword,
                enabled: !_saving,
                suffix: IconButton(
                  tooltip: _showPassword
                      ? l10n.editPlaylistHidePassword
                      : l10n.editPlaylistShowPassword,
                  icon: Icon(_showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              _liveFormatPicker(theme, l10n),
            ] else if (!_isFile)
              _Field(
                label: l10n.editPlaylistLink,
                ctrl: _url,
                hint: 'https://example.com/playlist.m3u',
                type: TextInputType.url,
                enabled: !_saving,
              ),
            _Field(
              label: l10n.editPlaylistGuideAddress,
              ctrl: _guide,
              hint: _isXtream
                  ? l10n.editPlaylistGuideAutoProvider
                  : l10n.editPlaylistGuideAutoPlaylist,
              type: TextInputType.url,
              enabled: !_saving,
            ),
            if (_isFile)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.editPlaylistFileNote,
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
                      l10n.editPlaylistLoginStored,
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
                      child: Text(
                          _stage == _SaveStage.checking
                              ? l10n.editPlaylistChecking
                              : l10n.editPlaylistUpdating,
                          style: theme.textTheme.bodyLarge)),
                ],
              )
            else
              TvActivatable(
                onTap: _save,
                borderRadius: BorderRadius.circular(28),
                builder: (onTap) => FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l10n.editPlaylistSave),
                ),
              ),
          ],
        )),
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
    this.autofocus = false,
  });

  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  final bool enabled;
  final bool autofocus;

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
          TvTextFieldGate(
            autofocus: autofocus,
            builder: (context, fieldNode) => TextField(
            controller: ctrl,
            focusNode: fieldNode,
            keyboardType: type,
            obscureText: obscure,
            enabled: enabled,
            // Playlist logins are never the device's saved logins: an empty hint
            // list stops Android autofill from pairing the URL with a saved password.
            autofillHints: const <String>[],
            autocorrect: false,
            enableSuggestions: !obscure && type != TextInputType.url,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.fieldBorderColor),
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
          ),
        ],
      ),
    );
  }
}
