import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../features/homework/homework_screen.dart' show weekPlanLinksProvider;
import '../../features/homework/week_letter.dart';
import '../../integrations/week_plans.dart';

/// The school's week plan, set up once per child.
///
/// An integration rather than an errand: the address is kept, the class row
/// is chosen once, and homework arrives with the ordinary sync — the same
/// shape a team's calendar feed has. Schools that publish nothing are not
/// worse off; the homework screen still takes a shared document, pasted
/// text, or a photograph of the board.
class SchoolPlansScreen extends ConsumerStatefulWidget {
  const SchoolPlansScreen({super.key});

  static const segment = 'school-plans';

  @override
  ConsumerState<SchoolPlansScreen> createState() => _SchoolPlansScreenState();
}

class _SchoolPlansScreenState extends ConsumerState<SchoolPlansScreen> {
  String? _busy;

  Future<void> _add() async {
    final l10n = context.l10n;
    final members = ref.read(membersProvider).value ?? const <Member>[];
    final children = [
      for (final m in members)
        if (m.isChild && m.isActive) m,
    ];
    if (children.isEmpty) return;

    final url = TextEditingController();
    var child = children.first.id;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.schoolPlanAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (children.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: child,
                  decoration: InputDecoration(labelText: l10n.hwWhose),
                  items: [
                    for (final c in children)
                      DropdownMenuItem(value: c.id, child: Text(c.displayName)),
                  ],
                  onChanged: (v) => setDialogState(() => child = v ?? child),
                ),
              TextField(
                controller: url,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.schoolPlanUrl,
                  hintText: l10n.schoolPlanUrlHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    final link = url.text.trim();
    url.dispose();
    if (added != true || link.isEmpty) return;

    final store = await ref.read(familyStoreProvider.future);
    final id = await store.saveWeekPlanLink(
      WeekPlanLinkPayload.write(memberId: child, url: link),
    );
    // Straight away, so the classes in the document can be offered while
    // the person who knows the answer is still standing here.
    if (mounted) await _chooseClass(id, link);
  }

  /// Which row of the school's table is this child's. Asked once, and the
  /// plan does nothing until it is answered: a document covers every class
  /// in the year.
  Future<void> _chooseClass(String id, String url) async {
    setState(() => _busy = id);
    final bytes = await WeekLetter.fetch(url);
    final classes = <String>[];
    if (bytes != null) {
      for (final table in WeekLetter.tablesIn(bytes)) {
        for (final c in classesIn(table)) {
          if (!classes.contains(c)) classes.add(c);
        }
      }
    }
    if (!mounted) return;
    setState(() => _busy = null);

    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.schoolPlanUnreadable)),
      );
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.whichClass),
        children: [
          for (final c in classes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c),
            ),
        ],
      ),
    );
    if (chosen == null) return;

    final store = await ref.read(familyStoreProvider.future);
    final existing = await store.payloadOf(id);
    if (existing == null) return;
    await store.saveWeekPlanLink(
      WeekPlanLinkPayload.read(existing).withGroup(chosen),
      id: id,
    );
    await _fetchNow(id);
  }

  Future<void> _fetchNow(String id) async {
    setState(() => _busy = id);
    final store = await ref.read(familyStoreProvider.future);
    final prefs = await ref.read(devicePreferencesProvider.future);
    final repository = await ref.read(familyRepositoryProvider.future);
    final added = await ref
        .read(weekPlansProvider)
        .refresh(store, prefs, timeZone: repository.timeZone, force: true);
    ref.read(syncControllerProvider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _busy = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.schoolPlanAdded(added))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final links = ref.watch(weekPlanLinksProvider).value ?? const [];
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolPlans)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l10n.schoolPlanAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(l10n.schoolPlansHelp, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (links.isEmpty)
            Text(
              l10n.schoolPlansEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final (id, link) in links)
            Card(
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(names[link.memberId] ?? l10n.someone),
                subtitle: Text(
                  link.group == null
                      ? l10n.schoolPlanNoClass
                      : '${link.group} · ${Uri.tryParse(link.url)?.host ?? ''}',
                ),
                trailing: _busy == id
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (choice) async {
                          switch (choice) {
                            case 'class':
                              await _chooseClass(id, link.url);
                            case 'now':
                              await _fetchNow(id);
                            case 'remove':
                              final store = await ref.read(
                                familyStoreProvider.future,
                              );
                              await store.deleteWeekPlanLink(id);
                              ref
                                  .read(syncControllerProvider.notifier)
                                  .syncNow();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'now',
                            child: Text(l10n.schoolPlanFetchNow),
                          ),
                          PopupMenuItem(
                            value: 'class',
                            child: Text(l10n.whichClass),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(l10n.removeDevice),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
