import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';
import 'recipes_screen.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../membership/permissions_provider.dart';
import '../members/diet_screen.dart';
import 'ideas_screen.dart';
import 'shopping_providers.dart';
import 'shopping_screen.dart';

final mealsProvider = StreamProvider<List<(String, MealPayload)>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchMeals();
});

/// The family's menu (spec §4 `meal_plan_entry`): a week of dinners picked
/// from the family's recipes, or just named ("Pizza out"), then onto the
/// shopping list in one go.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key, this.showing});

  static const segment = 'menu';

  /// A day whose week to open on, from a link that means that day:
  /// tonight's dinner on Today. Null opens the week being planned.
  final DateTime? showing;

  /// The menu opened on [day]'s week, as a link.
  static String pathShowing(DateTime day) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${ShoppingScreen.path}/$segment?day=${day.year}-${two(day.month)}-${two(day.day)}';
  }

  /// The day a link asked for, as `DateTime.utc` date fields, or null.
  static DateTime? dayFrom(String? value) {
    final d = value == null ? null : DateTime.tryParse(value);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }

  /// Monday of the week to open. Asked for a day, that day's week. Asked
  /// for nothing, the week being planned: from Friday that is the week
  /// ahead, since that is when the menu gets planned.
  ///
  /// Tonight's dinner on Today used to open like the latter, so on a
  /// Friday a tap on tonight's dinner showed next week's.
  static DateTime weekToOpen({required DateTime today, DateTime? showing}) {
    final day = showing ?? today;
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return showing == null && today.weekday >= DateTime.friday
        ? monday.add(const Duration(days: 7))
        : monday;
  }

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  /// Monday of the week shown (see [MenuScreen.weekToOpen]).
  late DateTime _week = () {
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    return MenuScreen.weekToOpen(
      today: DateTime.utc(now.year, now.month, now.day),
      showing: widget.showing,
    );
  }();

  int get _familySize => ref.read(membersProvider).value?.length ?? 4;

  Future<void> _addTo(
    DateTime day,
    (String, MealPayload)? existing, {
    String? chosenBy,
    String slot = 'dinner',
  }) async {
    final picked = await pickRecipe(context, ref);
    if (picked == null) return;
    final store = await ref.read(familyStoreProvider.future);
    final meal = existing?.$2;
    // The only caller that passes a meal is "add a side", so anything
    // arriving here on top of one is a side — even when the meal's main
    // was typed by hand and so left no recipe behind to count.
    final side = existing != null;
    await store.saveMeal(
      MealPayload.write(
        existing: meal?.payload,
        date: day,
        slot: meal == null ? slot : null,
        // Never the side's name. Potatoes added to the meatballs used to
        // rename the dinner Potatis and take the meatballs with it.
        title: side ? meal?.title : picked.$2,
        servings: meal?.servings ?? _familySize,
        cookMemberId: meal?.cookMemberId,
        chosenBy: chosenBy ?? meal?.chosenBy,
        recipes: [
          ...?meal?.recipes,
          if (picked.$1 case final id?)
            MealRecipe(recipeId: id, role: side ? 'side' : 'main')
          // A hand-typed side is kept beside the meal rather than in
          // place of it; on a new meal the name it was given is the
          // meal's own, so there is nothing to add.
          else if (side)
            MealRecipe(title: picked.$2, role: 'side'),
        ],
      ),
      id: existing?.$1,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  /// Which meals the family plans; never none, so dinner stays when the
  /// last one is taken off.
  Future<void> _setSlots(List<String> slots) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.saveSettings(
      settings.copyWith(mealSlots: slots.isEmpty ? const ['dinner'] : slots),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  Future<void> _toList() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final store = await ref.read(familyStoreProvider.future);
    var listId = await ref.read(currentListProvider.future);
    if (listId == null) {
      listId = await store.saveShoppingList(
        ShoppingListPayload.write(name: l10n.shoppingDefaultList),
      );
      await ref.read(currentListProvider.notifier).choose(listId);
    }
    await store.menuToList(
      listId,
      from: _week,
      until: _week.add(const Duration(days: 7)),
      defaultServings: _familySize,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    final name = (await ref.read(shoppingListsProvider.future))
        .where((l) => l.$1 == listId)
        .firstOrNull
        ?.$2
        .name;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.menuOnList(name ?? l10n.tabShopping))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final meals = ref.watch(mealsProvider).value ?? const [];
    final recipes = <String, RecipePayload>{
      for (final (id, r)
          in ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        id: r,
    };
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    final listId = ref.watch(currentListProvider).value;
    final listName =
        lists.where((l) => l.$1 == listId).firstOrNull?.$2.name ??
        l10n.tabShopping;
    final dayName = DateFormat('EEEE d/M');
    final permissions = ref.watch(permissionsProvider);
    final me = ref.watch(membershipProvider).value?.memberId;
    final weekEnd = _week.add(const Duration(days: 7));
    final chosen = [
      for (final (_, m) in meals)
        if (m.date case final d? when !d.isBefore(_week) && d.isBefore(weekEnd))
          m.chosenBy,
    ];
    final canPick = permissions.pickDinner(chosenThisWeek: chosen);
    final slots =
        ref.watch(settingsProvider).value?.mealSlots ??
        FamilySettings.defaults.mealSlots;
    final left = dinnerPicksLeft(
      ref.watch(membersProvider).value ?? const <Member>[],
      chosenThisWeek: chosen,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.menu),
        actions: [
          TextButton.icon(
            onPressed: () => context.go(
              '${ShoppingScreen.path}/${MenuScreen.segment}/${IdeasScreen.segment}',
            ),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(l10n.ideas),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _week = _week.subtract(const Duration(days: 7)),
                ),
              ),
              Text(
                l10n.weekNumber(isoWeekNumber(_week)),
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => _week = _week.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (canPick || permissions.planMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.star_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canPick
                          ? l10n.yourPickHint
                          : left.isEmpty
                          ? l10n.allPicked
                          : l10n.picksLeft(
                              left.map((m) => m.displayName).join(', '),
                            ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          // Which meals the family plans: dinner, and breakfast and lunch
          // if it wants them. Shared, so everyone plans the same days.
          if (permissions.planMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final slot in FamilySettings.allMealSlots)
                    FilterChip(
                      label: Text(mealSlotName(l10n, slot)),
                      selected: slots.contains(slot),
                      onSelected: (on) => _setSlots([
                        for (final s in FamilySettings.allMealSlots)
                          if (s == slot ? on : slots.contains(s)) s,
                      ]),
                    ),
                ],
              ),
            ),
          for (var i = 0; i < 7; i++) ...[
            if (slots.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(() {
                  final day = _week.add(Duration(days: i));
                  return DateFormat.EEEE()
                          .format(day)
                          .characters
                          .first
                          .toUpperCase() +
                      dayName.format(day).substring(1);
                }(), style: theme.textTheme.titleSmall),
              ),
            for (final slot in slots)
              () {
                final day = _week.add(Duration(days: i));
                final meal = meals
                    .where((m) => m.$2.date == day && m.$2.slot == slot)
                    .firstOrNull;
                // A child's pick is for dinner; breakfast and lunch are the
                // planners'.
                final canPickHere = canPick && slot == 'dinner';
                final what = meal?.$2.partsOf(recipes).join(' + ');
                final conflicts = [
                  for (final r in meal?.$2.recipes ?? const <MealRecipe>[])
                    if (recipes[r.recipeId] case final recipe?)
                      ...recipeConflicts(ref, recipe),
                ];
                return ListTile(
                  trailing: dietMark(context, conflicts),
                  title: Text(
                    slots.length > 1
                        ? mealSlotName(l10n, slot)
                        : DateFormat.EEEE()
                                  .format(day)
                                  .characters
                                  .first
                                  .toUpperCase() +
                              dayName.format(day).substring(1),
                    style: theme.textTheme.labelLarge,
                  ),
                  subtitle: meal == null
                      ? Text(
                          l10n.addDinner,
                          style: TextStyle(color: theme.colorScheme.primary),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              what!.isEmpty ? '—' : what,
                              style: theme.textTheme.bodyLarge,
                            ),
                            Text(
                              [
                                l10n.portionsCount(
                                  meal.$2.servings ?? _familySize,
                                ),
                                if (members[meal.$2.cookMemberId]
                                    case final name?)
                                  l10n.mealCookedBy(name),
                                if (members[meal.$2.chosenBy] case final name?)
                                  '★ ${l10n.pickOf(name)}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                  onTap: switch (meal) {
                    null when permissions.planMenu => () => _addTo(
                      day,
                      null,
                      slot: slot,
                    ),
                    null when canPickHere => () => _addTo(
                      day,
                      null,
                      chosenBy: me,
                      slot: slot,
                    ),
                    null => null,
                    final m when permissions.planMenu || m.$2.chosenBy == me =>
                      () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _MealSheet(
                          id: m.$1,
                          ref: ref,
                          onAddSide: () => _addTo(day, m),
                        ),
                      ),
                    _ => null,
                  },
                );
              }(),
          ],
        ],
      ),
      floatingActionButton: !permissions.shop
          ? null
          : FloatingActionButton.extended(
              onPressed: _toList,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(l10n.menuToList(listName)),
            ),
    );
  }
}

/// Changing one meal: its recipes, portions and cook.
class _MealSheet extends ConsumerWidget {
  const _MealSheet({
    required this.id,
    required this.ref,
    required this.onAddSide,
  });

  final String id;
  final WidgetRef ref;
  final VoidCallback onAddSide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final meal = (ref.watch(mealsProvider).value ?? const [])
        .where((m) => m.$1 == id)
        .firstOrNull
        ?.$2;
    if (meal == null) return const SizedBox(height: 120);
    final recipes = <String, RecipePayload>{
      for (final (rid, r)
          in ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        rid: r,
    };
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final servings = meal.servings ?? members.length;

    Future<void> save({
      int? servings,
      String? cook,
      bool clearCook = false,
      String? chosenBy,
      bool clearChosenBy = false,
      List<MealRecipe>? recipes,
    }) async {
      final store = await ref.read(familyStoreProvider.future);
      await store.saveMeal(
        MealPayload.write(
          existing: meal.payload,
          date: meal.date!,
          title: meal.title,
          servings: servings ?? meal.servings,
          cookMemberId: clearCook ? null : cook ?? meal.cookMemberId,
          chosenBy: clearChosenBy ? null : chosenBy ?? meal.chosenBy,
          recipes: recipes ?? meal.recipes,
        ),
        id: id,
      );
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (meal.title case final t?)
              Text(t, style: theme.textTheme.titleMedium),
            for (final (i, r) in meal.recipes.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant_menu),
                title: Text(recipes[r.recipeId]?.title ?? r.title ?? '—'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  // By position: two hand-typed sides share the empty
                  // recipe id, and removing by id would take both.
                  onPressed: () => save(
                    recipes: [
                      for (final (j, x) in meal.recipes.indexed)
                        if (j != i) x,
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAddSide();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addSide),
            ),
            TextButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final day = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 7)),
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 90)),
                );
                if (day == null) return;
                final store = await ref.read(familyStoreProvider.future);
                // Spec §4 "From a previous meal": the same recipes and
                // portions, on a new day; who cooks is decided afresh.
                await store.saveMeal(
                  MealPayload.write(
                    date: DateTime.utc(day.year, day.month, day.day),
                    title: meal.title,
                    servings: meal.servings,
                    recipes: meal.recipes,
                  ),
                );
                ref.read(syncControllerProvider.notifier).syncNow();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.replay),
              label: Text(l10n.cookAgain),
            ),
            const Divider(),
            Row(
              children: [
                Text(l10n.recipeServings, style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  onPressed: servings > 1
                      ? () => save(servings: servings - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$servings', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: () => save(servings: servings + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (ref.watch(permissionsProvider).planMenu)
              DropdownButtonFormField<String?>(
                initialValue: meal.chosenBy,
                decoration: InputDecoration(labelText: l10n.whosePick),
                items: [
                  DropdownMenuItem(child: Text(l10n.calendarLinkNoOne)),
                  for (final m in members.where((m) => m.isChild))
                    DropdownMenuItem(value: m.id, child: Text(m.displayName)),
                ],
                onChanged: (m) => save(chosenBy: m, clearChosenBy: m == null),
              ),
            DropdownButtonFormField<String?>(
              initialValue: meal.cookMemberId,
              decoration: InputDecoration(labelText: l10n.whoCooks),
              items: [
                DropdownMenuItem(child: Text(l10n.nobodyYet)),
                for (final m in members)
                  DropdownMenuItem(value: m.id, child: Text(m.displayName)),
              ],
              onChanged: (m) => save(cook: m, clearCook: m == null),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () async {
                final store = await ref.read(familyStoreProvider.future);
                await store.delete(ObjectKind.meal, id);
                ref.read(syncControllerProvider.notifier).syncNow();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(l10n.removeMeal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks a family recipe, or names something that isn't one: (recipe id,
/// null) or (null, title). Null if nothing was picked.
Future<(String?, String?)?> pickRecipe(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<(String?, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => _RecipePicker(ref: ref, scroll: scroll),
      ),
    );

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.ref, required this.scroll});

  final WidgetRef ref;
  final ScrollController scroll;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  final _search = TextEditingController();
  final _other = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final recipes = <(String, RecipePayload)>[
      for (final r
          in widget.ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        if (query.isEmpty || r.$2.title.toLowerCase().contains(query)) r,
    ];
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _other,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.somethingElse,
            hintText: l10n.mealTitleHint,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                if (_other.text.trim().isNotEmpty) {
                  Navigator.pop(context, (null, _other.text.trim()));
                }
              },
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, (null, v.trim()));
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.searchRecipes,
          ),
        ),
        // Planning dinner is exactly when you find the recipe you meant to
        // keep. Importing here puts it on this meal, rather than sending
        // you to Recipes and back again.
        ListTile(
          leading: const Icon(Icons.add_link),
          title: Text(l10n.importRecipe),
          subtitle: Text(l10n.importRecipeFromPlanning),
          onTap: () async {
            final id = await importRecipe(context);
            if (id != null && context.mounted) {
              Navigator.pop(context, (id, null));
            }
          },
        ),
        if (recipes.isEmpty && query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noRecipesFound(query),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final (id, r) in recipes)
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: Text(r.title),
            trailing: dietMark(context, recipeConflicts(widget.ref, r)),
            subtitle: r.minutes == null
                ? null
                : Text(l10n.recipeMinutes(r.minutes!)),
            onTap: () => Navigator.pop(context, (id, null)),
          ),
      ],
    );
  }
}

/// A meal's name: breakfast, lunch or dinner.
String mealSlotName(AppLocalizations l10n, String slot) => switch (slot) {
  'breakfast' => l10n.mealBreakfast,
  'lunch' => l10n.mealLunch,
  _ => l10n.mealDinner,
};
