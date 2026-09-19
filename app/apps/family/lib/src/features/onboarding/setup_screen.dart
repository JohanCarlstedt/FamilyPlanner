import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import '../../common/member_style.dart';

import 'package:timezone/timezone.dart' as tz;

import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../events/new_event_screen.dart';
import '../integrations/linked_calendars_screen.dart';
import '../members/members_screen.dart';
import '../recovery/recovery_kit_flow.dart';
import '../today/today_screen.dart';
import 'first_week.dart';
import 'setup_progress.dart';

/// The founder's first minutes in a new family (spec §9 "Getting to a useful
/// first week"): children before anything else, then a usual week so the
/// calendar isn't blank, then what the encryption means, said once and
/// plainly.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  static const path = '/setup';

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  // Back after a restart with the week written: straight to the words.
  late var _page = ref.read(setupProgressProvider).value == SetupProgress.seeded
      ? 3
      : 0;
  late final _pages = PageController(initialPage: _page);

  /// The usual week, by key: `school:<member id>` and `dinner`. Built when
  /// the page is first shown, from who's in the family by then.
  Map<String, WeekBlock>? _blocks;
  final _chosen = <String>{};
  late var _seeded =
      ref.read(setupProgressProvider).value == SetupProgress.seeded;

  Map<String, WeekBlock> _defaultBlocks(
    AppLocalizations l10n,
    List<Member> members,
  ) => {
    for (final m in members.where((m) => m.isChild))
      'school:${m.id}': WeekBlock(
        title: m.tier == MaturityTier.little
            ? l10n.seedPreschool
            : l10n.seedSchool,
        from: const TimeOfDay(hour: 8, minute: 0),
        to: m.tier == MaturityTier.little
            ? const TimeOfDay(hour: 16, minute: 0)
            : const TimeOfDay(hour: 14, minute: 0),
        memberId: m.id,
      ),
    'dinner': WeekBlock(
      title: l10n.seedDinner,
      from: const TimeOfDay(hour: 17, minute: 30),
      to: const TimeOfDay(hour: 18, minute: 0),
      weekdaysOnly: false,
    ),
  };

  Future<void> _pickTimes(String key) async {
    final block = _blocks![key]!;
    final from = await showTimePicker(
      context: context,
      initialTime: block.from,
    );
    if (from == null || !mounted) return;
    final to = await showTimePicker(context: context, initialTime: block.to);
    if (to == null || !mounted) return;
    setState(() => _blocks![key] = block.copyWith(from: from, to: to));
  }

  /// Writes the chosen blocks, once.
  Future<void> _seed() async {
    if (_seeded || _blocks == null) return;
    _seeded = true;
    final store = await ref.read(familyStoreProvider.future);
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    for (final event in firstWeekEvents(
      today: DateTime.utc(now.year, now.month, now.day),
      timeZone: familyTimeZone,
      blocks: [for (final k in _chosen) _blocks![k]!],
    )) {
      await store.saveEvent(event);
    }
    await ref.read(setupProgressProvider.notifier).set(SetupProgress.seeded);
    await ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 1) _seed();
    _pages.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        l10n.setupWhoTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.setupWhoBody, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      for (final (i, m) in members.indexed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: MemberStyle.colorOf(m, i),
                          ),
                          title: Text(m.displayName),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => editMember(context, ref),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: Text(l10n.addChild),
                      ),
                    ],
                  ),
                  _week(context, members),
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.setupPrivacyTitle,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.setupPrivacyBody,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  // Spec §9 step 7: setup isn't finished until the words
                  // are written down and checked.
                  RecoveryKitFlow(
                    onDone: () async {
                      await ref
                          .read(setupProgressProvider.notifier)
                          .set(SetupProgress.none);
                      if (context.mounted) context.go(TodayScreen.path);
                    },
                  ),
                ],
              ),
            ),
            if (_page < 3)
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _next, child: Text(l10n.next)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _week(BuildContext context, List<Member> members) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final names = {for (final m in members) m.id: m.displayName};
    if (_blocks == null && _page >= 1) {
      _blocks = _defaultBlocks(l10n, members);
      _chosen.addAll(_blocks!.keys);
    }
    final blocks = _blocks ?? const <String, WeekBlock>{};
    String at(TimeOfDay t) =>
        MaterialLocalizations.of(context)
            .formatTimeOfDay(t, alwaysUse24HourFormat: true);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.setupWeekTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l10n.setupWeekBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        for (final MapEntry(key: key, value: b) in blocks.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _chosen.contains(key),
            onChanged: (on) => setState(
              () => on == true ? _chosen.add(key) : _chosen.remove(key),
            ),
            title: Text(
              b.memberId == null
                  ? b.title
                  : l10n.seedBlockFor(names[b.memberId] ?? '', b.title),
            ),
            subtitle: InkWell(
              onTap: () => _pickTimes(key),
              child: Text(
                (b.weekdaysOnly ? l10n.seedWeekdays : l10n.seedEveryDay)(
                  at(b.from),
                  at(b.to),
                ),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sports_soccer_outlined),
          title: Text(l10n.seedActivity),
          subtitle: Text(l10n.seedActivitySubtitle),
          onTap: () =>
              context.push('${TodayScreen.path}/${NewEventScreen.segment}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_repeat),
          title: Text(l10n.linkCalendar),
          subtitle: Text(l10n.linkedCalendarsSubtitle),
          onTap: () => openCalendarLink(context, ref),
        ),
      ],
    );
  }
}
