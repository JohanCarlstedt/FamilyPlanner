import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import 'homework_screen.dart' show homeworkTypeName;
import 'week_letter.dart';

/// A teacher's week letter, turned into homework someone has agreed to.
///
/// The parser guesses — letters are written differently by every teacher
/// and rewritten every term — so everything it finds is shown first, with
/// what it thinks the deadline and subject are, and nothing is saved until
/// a person says so.
class WeekLetterScreen extends ConsumerStatefulWidget {
  const WeekLetterScreen({super.key, this.file, this.text});

  static const segment = 'week-letter';

  /// A document shared into the app, if that is how it arrived.
  final File? file;

  /// Text pasted instead.
  final String? text;

  @override
  ConsumerState<WeekLetterScreen> createState() => _WeekLetterScreenState();
}

class _WeekLetterScreenState extends ConsumerState<WeekLetterScreen> {
  final _pasted = TextEditingController();
  List<HomeworkCandidate>? _found;
  final _chosen = <int>{};
  String? _child;
  var _unreadable = false;

  @override
  void initState() {
    super.initState();
    if (widget.text case final text?) _pasted.text = text;
    _read();
  }

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    var text = _pasted.text;
    if (text.isEmpty && widget.file != null) {
      final read = await WeekLetter.textOf(widget.file!);
      if (read == null) {
        if (mounted) setState(() => _unreadable = true);
        return;
      }
      text = read;
      _pasted.text = read;
    }
    if (text.trim().isEmpty) return;
    final repository = await ref.read(familyRepositoryProvider.future);
    final found = WeekLetter.read(text, timeZone: repository.timeZone);
    if (!mounted) return;
    setState(() {
      _found = found;
      // Everything it found is ticked: the common case is that the letter
      // is right and the reader is only checking.
      _chosen
        ..clear()
        ..addAll(List.generate(found.length, (i) => i));
    });
  }

  Future<void> _save() async {
    final found = _found;
    final child = _child;
    if (found == null || child == null) return;
    final store = await ref.read(familyStoreProvider.future);
    final me = ref.read(membershipProvider).value?.memberId;
    for (final i in _chosen) {
      final h = found[i];
      await store.saveHomework(
        HomeworkPayload.write(
          memberId: child,
          title: h.title,
          type: h.type,
          // No deadline read from the letter means today's date rather than
          // a guessed one: a wrong date is worse than an obvious gap.
          dueAt: h.dueAt ?? DateTime.now().toUtc(),
          source: me == child ? 'child' : 'import',
        ),
      );
    }
    ref.read(syncControllerProvider.notifier).syncNow();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final children = [
      for (final m in members)
        if (m.isChild && m.isActive) m,
    ];
    _child ??= children.length == 1 ? children.first.id : null;
    final found = _found;
    final date = DateFormat('EEEE d MMMM', l10n.localeName);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weekLetter)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_unreadable)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.weekLetterUnreadable),
              ),
            ),
          Text(l10n.weekLetterHelp, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _pasted,
            maxLines: 8,
            minLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l10n.weekLetterPaste,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _read,
              child: Text(l10n.weekLetterRead),
            ),
          ),
          if (found != null) ...[
            const Divider(height: 32),
            if (found.isEmpty)
              Text(
                l10n.weekLetterNothing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (children.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: _child,
                  decoration: InputDecoration(labelText: l10n.hwWhose),
                  items: [
                    for (final c in children)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _child = v),
                ),
              for (final (i, h) in found.indexed)
                CheckboxListTile(
                  value: _chosen.contains(i),
                  onChanged: (on) => setState(
                    () => on! ? _chosen.add(i) : _chosen.remove(i),
                  ),
                  title: Text(h.title),
                  subtitle: Text(
                    [
                      ?h.subject,
                      if (h.dueAt case final due?)
                        date.format(due)
                      else
                        l10n.weekLetterNoDate,
                      if (h.type != HomeworkType.assignment)
                        homeworkTypeName(l10n, h.type),
                    ].join(' · '),
                  ),
                ),
            ],
          ],
        ],
      ),
      floatingActionButton: switch ((found, _child)) {
        (final f?, final c?) when f.isNotEmpty && _chosen.isNotEmpty && c != '' =>
          FloatingActionButton.extended(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l10n.weekLetterSave(_chosen.length)),
          ),
        _ => null,
      },
    );
  }
}
