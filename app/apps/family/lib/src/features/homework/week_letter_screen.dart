import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  const WeekLetterScreen({super.key, this.file, this.text, this.link});

  static const segment = 'week-letter';

  /// A document shared into the app, if that is how it arrived.
  final File? file;

  /// Text pasted instead.
  final String? text;

  /// A link someone shared, which cannot be fetched: a school's SharePoint
  /// answers 401 to anyone outside its tenant.
  final String? link;

  @override
  ConsumerState<WeekLetterScreen> createState() => _WeekLetterScreenState();
}

class _WeekLetterScreenState extends ConsumerState<WeekLetterScreen> {
  final _pasted = TextEditingController();
  List<HomeworkCandidate>? _found;
  final _chosen = <int>{};
  String? _child;
  var _unreadable = false;
  var _reading = false;

  /// A school's week overview covers every class in one table; this is the
  /// family's. Remembered per device, because it does not change weekly.
  List<String> _classes = const [];
  String? _class;
  List<WeekPlanEntry> _plan = const [];
  static const _classPreference = 'homework.class';

  /// The saved link this screen was opened from, if it was.
  String? _savedLinkId;

  /// A link pasted here rather than shared in, so it can be kept too.
  String? _fetched;

  @override
  void initState() {
    super.initState();
    if (widget.text case final text?) _pasted.text = text;
    if (widget.link case final link?) {
      _readLink(link);
    } else {
      _read();
    }
  }

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  /// A shared link, fetched here on the phone. SharePoint hands the file
  /// to something that looks like a browser, which is the whole trick.
  Future<void> _readLink(String url) async {
    setState(() {
      _reading = true;
      _fetched = url;
    });
    final bytes = await WeekLetter.fetch(url);
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _reading = false;
        _unreadable = true;
      });
      return;
    }
    await _readTables(WeekLetter.tablesIn(bytes), fallback: bytes);
  }

  /// The tables a week overview is made of, or the text if it has none.
  Future<void> _readTables(
    List<List<List<String>>> tables, {
    List<int>? fallback,
  }) async {
    final repository = await ref.read(familyRepositoryProvider.future);
    final prefs = await ref.read(devicePreferencesProvider.future);
    final remembered = await prefs.read(_classPreference);

    final classes = <String>[];
    final entries = <WeekPlanEntry>[];
    for (final table in tables) {
      for (final c in classesIn(table)) {
        if (!classes.contains(c)) classes.add(c);
      }
      entries.addAll(
        readWeekPlan(table, timeZone: repository.timeZone),
      );
    }
    if (!mounted) return;

    if (entries.isEmpty) {
      // Not a week overview after all: read it as a letter instead.
      if (fallback != null) {
        final text = WeekLetter.textOfBytes(fallback);
        if (text != null) {
          _pasted.text = text;
          setState(() => _reading = false);
          await _read();
          return;
        }
      }
      setState(() {
        _reading = false;
        _found = const [];
      });
      return;
    }

    setState(() {
      _reading = false;
      _classes = classes;
      _class = classes.contains(remembered)
          ? remembered
          : (classes.length == 1 ? classes.first : null);
      _plan = entries;
    });
    _showClass(_class);
  }

  /// Keeps this week overview for next week too, against one child.
  ///
  /// Saved rather than pasted every Sunday — and against the child, not the
  /// family, because siblings are in different classes and often different
  /// schools.
  Future<void> _remember() async {
    final child = _child;
    final link = widget.link ?? _fetched;
    if (child == null || link == null) return;
    final store = await ref.read(familyStoreProvider.future);
    final id = await store.saveWeekPlanLink(
      WeekPlanLinkPayload.write(
        memberId: child,
        url: link,
        group: _class,
      ),
      id: _savedLinkId,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _savedLinkId = id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.weekPlanRemembered)));
  }

  /// The chosen class's homework, as candidates to tick.
  void _showClass(String? group) {
    final mine = [
      for (final e in _plan)
        if (group == null || e.group == group)
          HomeworkCandidate(
            title: e.title,
            dueAt: e.dueAt,
            subject: e.subject,
            type: e.type,
          ),
    ];
    setState(() {
      _class = group;
      _found = mine;
      _chosen
        ..clear()
        ..addAll(List.generate(mine.length, (i) => i));
    });
  }

  Future<void> _read() async {
    var text = _pasted.text;

    // A link pasted into the box is the obvious thing to try, and it is a
    // link to fetch rather than a letter to read: pasted as text it would
    // be a line of URL with no homework in it.
    final pasted = text.trim();
    if (WeekLetter.looksLikeDocument(pasted)) {
      await _readLink(pasted);
      return;
    }

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

  /// A photograph of the whiteboard, which is how homework actually
  /// leaves a classroom. Read on this phone; the picture is not kept.
  Future<void> _photo(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Small enough to handle, large enough for the text to survive.
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null) return;
    setState(() => _reading = true);
    final text = await WeekLetter.textOfPhoto(File(picked.path));
    if (!mounted) return;
    setState(() {
      _reading = false;
      _unreadable = text == null;
      if (text != null) _pasted.text = text;
    });
    if (text != null) await _read();
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
          // Only when the fetch failed: a link that needs a real sign-in,
          // or one whose host we cannot ask.
          if (widget.link != null && _unreadable)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.link_off),
                title: Text(l10n.weekLetterLinkShared),
                subtitle: Text(l10n.weekLetterLinkSharedHelp),
              ),
            ),
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
              hintText: l10n.weekLetterPasteOrLink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // The whiteboard, photographed on the way out of school.
              OutlinedButton.icon(
                onPressed: _reading ? null : () => _photo(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.weekLetterPhoto),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.choosePhoto,
                onPressed: _reading ? null : () => _photo(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _reading ? null : _read,
                child: Text(l10n.weekLetterRead),
              ),
            ],
          ),
          if (_reading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
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
              if (_classes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: _class,
                    decoration: InputDecoration(labelText: l10n.whichClass),
                    items: [
                      for (final c in _classes)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) async {
                      _showClass(v);
                      if (v == null) return;
                      final prefs = await ref.read(
                        devicePreferencesProvider.future,
                      );
                      await prefs.write(_classPreference, v);
                    },
                  ),
                ),
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
              if ((widget.link ?? _fetched) != null && _child != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _remember,
                    icon: Icon(
                      _savedLinkId == null
                          ? Icons.bookmark_add_outlined
                          : Icons.bookmark_added,
                    ),
                    label: Text(
                      _savedLinkId == null
                          ? l10n.weekPlanRemember
                          : l10n.weekPlanRemembered,
                    ),
                  ),
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
