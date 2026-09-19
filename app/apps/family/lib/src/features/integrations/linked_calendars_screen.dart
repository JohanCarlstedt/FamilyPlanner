import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../integrations/calendar_feeds.dart';

/// Calendars linked to members (docs/roadmap.md "Integrations"): a team's
/// feed, fetched by this phone and shown as the child's events.
class LinkedCalendarsScreen extends ConsumerWidget {
  const LinkedCalendarsScreen({super.key});

  static const segment = 'calendars';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final links = ref.watch(calendarLinksProvider);
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };

    final note = Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.calendarPrivacyNote,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkedCalendars)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCalendarLink(context, ref),
        icon: const Icon(Icons.add_link),
        label: Text(l10n.linkCalendar),
      ),
      body: switch (links) {
        AsyncValue(value: final list?) when list.isEmpty => ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.linkedCalendarsEmpty,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            note,
          ],
        ),
        AsyncValue(value: final list?) => ListView(
          children: [
            for (final (id, link) in list)
              ListTile(
                leading: const Icon(Icons.event_repeat),
                onTap: () => openCalendarLink(context, ref, id: id, link: link),
                title: Text(link.name),
                subtitle: Text(
                  [?names[link.memberId], Uri.parse(link.url).host].join(' · '),
                ),
                trailing: PopupMenuButton<_Action>(
                  onSelected: (action) => switch (action) {
                    _Action.fetch => _fetch(context, ref, id, link),
                    _Action.remove => _remove(context, ref, id, link),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _Action.fetch,
                      child: Text(l10n.fetchNow),
                    ),
                    PopupMenuItem(
                      value: _Action.remove,
                      child: Text(l10n.unlinkCalendar),
                    ),
                  ],
                ),
              ),
            note,
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String id,
    CalendarLinkPayload link,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unlinkCalendarTitle(link.name)),
        content: Text(l10n.unlinkCalendarBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.unlinkCalendar),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.unlinkFeed(id);
    await ref.read(syncControllerProvider.notifier).syncNow();
  }
}

enum _Action { fetch, remove }

/// Links a calendar, or edits [link].
Future<void> openCalendarLink(
  BuildContext context,
  WidgetRef ref, {
  String? id,
  CalendarLinkPayload? link,
  String? initialUrl,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _LinkDialog(ref: ref, id: id, link: link, initialUrl: initialUrl),
);

/// Fetches [link] now and says how it went.
Future<void> _fetch(
  BuildContext context,
  WidgetRef ref,
  String id,
  CalendarLinkPayload link,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final store = await ref.read(familyStoreProvider.future);
    final changed = await ref
        .read(calendarFeedsProvider)
        .fetch(store, id, link);
    await store.setDevicePreference(
      'feed.fetched.$id',
      DateTime.now().toUtc().toIso8601String(),
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.calendarFetched(changed))),
    );
    await ref.read(syncControllerProvider.notifier).syncNow();
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.calendarFetchFailed('$e'))),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.ref, this.id, this.link, this.initialUrl});

  /// A link shared to the app from elsewhere, filled in for them.
  final String? initialUrl;

  final WidgetRef ref;

  /// The link being edited; null when adding one.
  final String? id;
  final CalendarLinkPayload? link;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _url = TextEditingController(
    text: widget.link?.url ?? widget.initialUrl,
  );
  late final _name = TextEditingController(text: widget.link?.name);
  late String? _memberId = widget.link?.memberId;
  late String? _responsible = widget.link?.responsibleMemberId;

  /// The name last filled in from the link; replaced as the link is typed,
  /// until the person writes their own.
  String? _suggested;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  /// A laget.se link names the team; offer that as the name.
  void _suggestName(String text) {
    if (_name.text.isNotEmpty && _name.text != _suggested) return;
    final url = feedUrl(text);
    final uri = url == null ? null : Uri.parse(url);
    final suggestion = uri?.host == 'cal.laget.se'
        ? uri!.pathSegments.last.replaceAll('.ics', '').replaceAll('_', ' ')
        : '';
    _name.text = suggestion;
    _suggested = suggestion;
  }

  Future<void> _save(List<Member> members) async {
    final l10n = context.l10n;
    final url = feedUrl(_url.text);
    final memberId = _memberId ?? members.firstOrNull?.id;
    if (url == null || memberId == null) {
      setState(() => _error = l10n.calendarLinkInvalid);
      return;
    }
    final linked = widget.ref.read(calendarLinksProvider).value ?? const [];
    if (linked.any((l) => l.$2.url == url && l.$1 != widget.id)) {
      setState(() => _error = l10n.calendarAlreadyLinked);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ref = widget.ref;
    final link = CalendarLinkPayload.write(
      existing: widget.link?.payload,
      memberId: memberId,
      responsibleMemberId: _responsible,
      name: _name.text.trim().isEmpty ? Uri.parse(url).host : _name.text.trim(),
      url: url,
    );
    final store = await ref.read(familyStoreProvider.future);
    // Fetch before saving, so a wrong link is caught while it can be fixed.
    if (url != widget.link?.url) {
      try {
        await ref.read(calendarFeedsProvider).download(url);
      } on Object catch (e) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error = l10n.calendarFetchFailed('$e');
          });
        }
        return;
      }
    }
    final id = await store.saveCalendarLink(link, id: widget.id);
    if (widget.link case final was? when was.memberId != memberId) {
      await store.relinkFeed(id, from: was.memberId, to: memberId);
    }
    if (!mounted) return;
    // Fetched while the dialog is still up: once it's closed, its context
    // can't report how it went.
    await _fetch(context, ref, id, link);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = widget.ref.watch(membersProvider).value ?? const <Member>[];
    // Children first: a team calendar is usually theirs.
    final members = [
      ...all.where((m) => m.isChild),
      ...all.where((m) => !m.isChild),
    ];
    return AlertDialog(
      title: Text(
        widget.link == null ? l10n.linkCalendar : l10n.editCalendarLink,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              autofocus: widget.link == null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: _suggestName,
              decoration: InputDecoration(
                labelText: l10n.calendarLinkUrl,
                helperText: l10n.calendarLinkUrlHint,
                helperMaxLines: 2,
                errorText: _error,
                errorMaxLines: 4,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _memberId ?? members.firstOrNull?.id,
              decoration: InputDecoration(labelText: l10n.calendarLinkFor),
              items: [
                for (final m in members)
                  DropdownMenuItem(value: m.id, child: Text(m.displayName)),
              ],
              onChanged: (id) => setState(() => _memberId = id),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _responsible,
              decoration: InputDecoration(
                labelText: l10n.calendarLinkResponsible,
              ),
              items: [
                DropdownMenuItem(child: Text(l10n.calendarLinkNoOne)),
                for (final m in all.where((m) => m.role == MemberRole.parent))
                  DropdownMenuItem(value: m.id, child: Text(m.displayName)),
              ],
              onChanged: (id) => setState(() => _responsible = id),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.calendarLinkName),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(members),
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
