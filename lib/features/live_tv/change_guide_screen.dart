import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/epg/guide_matcher.dart';
import 'package:open_iptv/core/services/guide_assignment_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Hold OK / long-press a channel → Change Guide: pick which guide channel
/// supplies a channel's programmes (#40). A manual choice beats everything,
/// including the playlist's own guide.
class ChangeGuideScreen extends ConsumerStatefulWidget {
  const ChangeGuideScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  @override
  ConsumerState<ChangeGuideScreen> createState() => _ChangeGuideScreenState();
}

class _ChangeGuideScreenState extends ConsumerState<ChangeGuideScreen> {
  final _query = TextEditingController();
  GuidePicker? _picker;
  GuideLinkRow? _link;
  List<GuideChannel> _results = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_search);
    unawaited(_load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final picker = await ref.read(guideAssignmentProvider).loadPicker();
    final link =
        await ref.read(appDatabaseProvider).getGuideLink(widget.channelId);
    if (!mounted) return;
    setState(() {
      _picker = picker;
      _link = link;
    });
    _search();
  }

  void _search() {
    final picker = _picker;
    if (picker == null) return;
    final q = _query.text.trim();
    setState(() {
      _results = q.isEmpty
          ? picker.matcher.suggest(widget.channelName)
          : picker.matcher.search(q, like: widget.channelName);
    });
  }

  String _describe(GuideLinkRow? link, GuidePicker picker) {
    if (link == null) {
      return "Using the playlist's own guide (or a smart match, if it has none)";
    }
    if (link.xmltvId == null) return 'No guide, as you chose';
    final guide = picker.guideNames[link.guideRef] ?? 'a guide';
    final how = link.kind == 'manual' ? 'You chose' : 'Matched automatically to';
    return '$how ${link.xmltvId} in $guide';
  }

  Future<void> _apply(Future<void> Function(GuideAssignmentService) change,
      String message,
      {bool loadProgrammes = false}) async {
    final service = ref.read(guideAssignmentProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final revision = ref.read(guideRevisionProvider.notifier);
    await change(service);
    revision.state++;
    if (mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(
        content: Text(message),
        // Stays up while a guide is being read; replaced when it finishes.
        duration: loadProgrammes ? const Duration(minutes: 5) : const Duration(seconds: 4)));
    if (loadProgrammes) {
      // Only this channel's programmes, from its one guide: seconds, not the
      // minutes a full sync takes, and never lost to a sync already running.
      unawaited(service.loadChannel(widget.channelId).then((problem) {
        revision.state++;
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(SnackBar(
            content: Text(problem ?? 'Guide loaded.')));
      }));
    } else {
      // "Use Automatic" may need a smart match or the playlist's guide.
      unawaited(service.sync(refreshLists: false).whenComplete(() {
        revision.state++;
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picker = _picker;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Guide')),
      body: picker == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                ListTile(
                  title: Text(widget.channelName,
                      style: theme.textTheme.titleMedium),
                  subtitle: Text(_describe(_link, picker)),
                ),
                const SizedBox(height: 8),
                if (picker.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('No guides to pick from yet'),
                    subtitle: Text(
                        'Add one in Settings → Live TV → Extra Guides, or '
                        'refresh your TV guides.'),
                  )
                else ...[
                  TvTextFieldGate(
                    builder: (context, fieldNode) => TextField(
                      focusNode: fieldNode,
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search the guides',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      _query.text.trim().isEmpty ? 'Suggested' : 'Results',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                  if (_results.isEmpty)
                    const ListTile(title: Text('Nothing found')),
                  for (final g in _results)
                    TvActivatable(
                      onTap: () => _apply(
                        (s) => s.setManual(
                            widget.channelId, g.guideId, g.xmltvId),
                        'Guide changed. Loading programmes, this can take a minute…',
                        loadProgrammes: true,
                      ),
                      builder: (tap) => ListTile(
                        leading: Icon(
                          _link?.xmltvId == g.xmltvId &&
                                  _link?.guideRef == g.guideId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(g.name),
                        subtitle: Text(
                            '${picker.guideNames[g.guideId] ?? 'Guide'} · ${g.xmltvId}'),
                        onTap: tap,
                      ),
                    ),
                ],
                const Divider(height: 32),
                TvActivatable(
                  onTap: () => _apply(
                      (s) => s.setNone(widget.channelId), 'Guide removed.'),
                  builder: (tap) => ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('No Guide for This Channel'),
                    subtitle: const Text(
                        'Clears its programmes and keeps it that way'),
                    onTap: tap,
                  ),
                ),
                if (_link != null)
                  TvActivatable(
                    onTap: () => _apply((s) => s.resetLink(widget.channelId),
                        'Back to automatic.'),
                    builder: (tap) => ListTile(
                      leading: const Icon(Icons.restart_alt_rounded),
                      title: const Text('Use Automatic'),
                      subtitle: const Text(
                          "The playlist's own guide, or a smart match"),
                      onTap: tap,
                    ),
                  ),
              ],
            ),
    );
  }
}
