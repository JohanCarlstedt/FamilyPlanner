import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../common/clock.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../shopping/menu_screen.dart' show mealsProvider;
import '../shopping/shopping_providers.dart';
import '../shopping/shopping_screen.dart' show aisleName;

/// What the wall tablet shows, resolved for one instant: two days of the
/// family's calendar and the week's meals.
class KitchenState {
  const KitchenState({
    required this.days,
    required this.members,
    required this.location,
    required this.now,
  });

  final List<DayAgenda> days;
  final List<Member> members;
  final tz.Location location;
  final DateTime now;

  tz.TZDateTime local(DateTime utc) => tz.TZDateTime.from(utc, location);
}

final kitchenProvider = FutureProvider<KitchenState>((ref) async {
  final repository = await ref.watch(familyRepositoryProvider.future);
  final now = await ref.watch(nowProvider.future);
  final members = await ref.watch(membersProvider.future);
  final events = await ref.watch(eventsProvider.future);
  final absences = await ref.watch(absencesProvider.future);
  final location = tz.getLocation(repository.timeZone);
  final today = tz.TZDateTime.from(now, location);

  const builder = DayAgendaBuilder();
  return KitchenState(
    days: [
      for (var i = 0; i < 2; i++)
        builder.build(
          events: events,
          members: members,
          day: DateTime(today.year, today.month, today.day + i),
          timeZone: repository.timeZone,
          now: now,
          absences: absences,
        ),
    ],
    members: members,
    location: location,
    now: now,
  );
});

/// The kitchen display (spec §11, architecture doc §4): a wall tablet
/// showing the day, what's for dinner and the shopping list, in type you
/// can read from the other side of the room and targets you can hit with a
/// wet hand. It holds no chat keys: anyone in the house can read it.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  static const path = '/kitchen';

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  @override
  void initState() {
    super.initState();
    // A display that goes dark is a picture frame. Failures are ignored:
    // the platform may not allow it, and the screen is still useful.
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _tick(String id, ShoppingItemPayload item) async {
    final store = await ref.read(familyStoreProvider.future);
    final bought = item.state == ItemState.bought;
    await store.saveShoppingItem(
      item.copyWith(
        state: bought ? ItemState.needed : ItemState.bought,
        checkedBy: ref.read(membershipProvider).value?.memberId,
        checkedAt: DateTime.now(),
      ),
      id: id,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kitchen = ref.watch(kitchenProvider);
    final state = kitchen.value;
    final kitchenDevice =
        ref.watch(membershipProvider).value?.isKitchen ?? false;

    if (state == null) {
      // A wall display that spins for ever tells nobody anything.
      return Scaffold(
        body: Center(
          child: kitchen.hasError
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${kitchen.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final today = state.local(state.now);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE d MMMM', l10n.localeName).format(today),
              style: theme.textTheme.displaySmall,
            ),
          ),
          Text(
            l10n.weekNumber(isoWeekNumber(today)),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!kitchenDevice)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IconButton.filledTonal(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );

    final panels = [
      _Panel(
        title: l10n.kitchenToday,
        child: _Days(state: state),
      ),
      _Panel(
        title: l10n.kitchenDinner,
        child: _Meals(state: state),
      ),
      _Panel(
        title: l10n.tabShopping,
        child: _ShoppingPanel(onTick: _tick),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, flex) in [3, 2, 2].indexed)
                          Expanded(
                            flex: flex,
                            child: SingleChildScrollView(child: panels[i]),
                          ),
                      ],
                    )
                  : ListView(children: panels),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          child,
        ],
      ),
    );
  }
}

/// Today and tomorrow, everyone's, in the family's zone.
class _Days extends ConsumerWidget {
  const _Days({required this.state});

  final KitchenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm');
    final colors = {
      for (final (i, m) in state.members.indexed)
        m.id: MemberStyle.colorOf(m, i),
    };
    final names = {for (final m in state.members) m.id: m.displayName};

    List<Widget> dayRows(DayAgenda day, {required bool tomorrow}) => [
      if (tomorrow)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
          child: Text(l10n.inDays(1), style: theme.textTheme.titleLarge),
        ),
      if (day.entries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            l10n.kitchenNothingOn,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      for (final entry in day.entries)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: Text(
              time.format(state.local(entry.start)),
              style: theme.textTheme.titleLarge,
            ),
            title: Text(entry.event.title, style: theme.textTheme.titleLarge),
            subtitle:
                entry.event.participantIds.isEmpty &&
                    entry.event.location == null
                ? null
                : Text(
                    [
                      for (final id in entry.event.participantIds) ?names[id],
                      ?entry.event.location,
                    ].join(' · '),
                    style: theme.textTheme.titleMedium,
                  ),
            trailing: entry.event.participantIds.isEmpty
                ? null
                : Wrap(
                    spacing: 4,
                    children: [
                      for (final id in entry.event.participantIds)
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              colors[id] ?? theme.colorScheme.outline,
                          foregroundColor: Colors.white,
                          child: Text(
                            (names[id] ?? '?').characters.first,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
    ];

    // A panel is a column: the display scrolls as a whole, and a scroll
    // view inside a scroll view lays out nothing at all.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...dayRows(state.days.first, tomorrow: false),
        if (state.days.length > 1) ...dayRows(state.days[1], tomorrow: true),
      ],
    );
  }
}

/// Tonight's dinner, large, and the rest of the week under it.
class _Meals extends ConsumerWidget {
  const _Meals({required this.state});

  final KitchenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final meals =
        ref.watch(mealsProvider).value ?? const <(String, MealPayload)>[];
    final recipes = <String, RecipePayload>{
      for (final (id, r)
          in ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        id: r,
    };
    final today = state.local(state.now);
    final day = DateTime.utc(today.year, today.month, today.day);
    final names = {for (final m in state.members) m.id: m.displayName};

    String? nameOf(MealPayload meal) {
      final parts = meal.partsOf(recipes);
      return parts.isEmpty ? null : parts.join(' + ');
    }

    final byDay = {
      for (final (_, m) in meals)
        if (m.date case final d? when !d.isBefore(day)) d: m,
    };
    final tonight = byDay[day];
    final rest = [
      for (var i = 1; i < 7; i++)
        if (byDay[day.add(Duration(days: i))] case final m?)
          (day.add(Duration(days: i)), m),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (tonight == null ? null : nameOf(tonight)) ??
                      l10n.kitchenNoDinner,
                  style: theme.textTheme.headlineMedium,
                ),
                if (tonight?.cookMemberId case final cook?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.mealCookedBy(names[cook] ?? l10n.someone),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final (date, meal) in rest)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: Text(
              DateFormat('EEE', l10n.localeName).format(date),
              style: theme.textTheme.titleMedium,
            ),
            title: Text(
              nameOf(meal) ?? '—',
              style: theme.textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}

/// The list, by aisle, with targets big enough to tick while cooking.
class _ShoppingPanel extends ConsumerWidget {
  const _ShoppingPanel({required this.onTick});

  final Future<void> Function(String, ShoppingItemPayload) onTick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final listId = ref.watch(currentListProvider).value;
    final items =
        [
          for (final (id, i)
              in ref.watch(shoppingItemsProvider).value ??
                  const <(String, ShoppingItemPayload)>[])
            if (i.listId == listId && i.state != ItemState.bought) (id, i),
        ]..sort((a, b) {
          final aisle = a.$2.category.index.compareTo(b.$2.category.index);
          return aisle != 0 ? aisle : a.$2.name.compareTo(b.$2.name);
        });

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          l10n.kitchenListEmpty,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Aisle? last;
    final rows = <Widget>[];
    for (final (id, item) in items) {
      if (item.category != last) {
        last = item.category;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text(
              aisleName(l10n, item.category),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      rows.add(
        InkWell(
          onTap: () => onTick(id, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.circle_outlined, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item.name, style: theme.textTheme.titleLarge),
                ),
                if (item.quantity != null)
                  Text(
                    describeAmount(item.quantity, item.unit, ''),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}
