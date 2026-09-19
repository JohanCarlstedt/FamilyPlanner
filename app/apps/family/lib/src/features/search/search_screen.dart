import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../actions/actions_providers.dart';
import '../actions/actions_screen.dart';
import '../events/event_detail_screen.dart';
import '../homework/homework_screen.dart';
import '../more/more_screen.dart';
import '../people/celebrations_screen.dart';
import '../people/wishlist_screen.dart';
import '../shopping/recipes_screen.dart';
import '../shopping/shopping_providers.dart';

/// Every event payload, for searching titles, places and notes.
final eventPayloadsProvider = StreamProvider<List<(String, EventPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchEvents();
});

/// Spec §12 "global search": across the family's calendar, recipes, to-dos,
/// homework and people, on this phone. Nothing is searchable anywhere else,
/// since nothing is readable anywhere else.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const path = '/search';

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = _query.text.trim().toLowerCase();
    bool hit(Iterable<String?> fields) =>
        fields.any((f) => f != null && f.toLowerCase().contains(q));

    final events = q.length < 2
        ? const <(String, EventPayload)>[]
        : [
            for (final e
                in ref.watch(eventPayloadsProvider).value ??
                    const <(String, EventPayload)>[])
              if (!e.$2.isDeleted &&
                  hit([e.$2.title, e.$2.location, e.$2.notes]))
                e,
          ];
    final recipes = q.length < 2
        ? const <(String, RecipePayload)>[]
        : [
            for (final r
                in ref.watch(recipesProvider).value ??
                    const <(String, RecipePayload)>[])
              if (hit([r.$2.title, ...r.$2.ingredients, r.$2.notes])) r,
          ];
    final todos = q.length < 2
        ? const <(String, ActionPayload)>[]
        : [
            for (final a
                in ref.watch(actionsProvider).value ??
                    const <(String, ActionPayload)>[])
              if (a.$2.isOpen && hit([a.$2.title, a.$2.description])) a,
          ];
    final homework = q.length < 2
        ? const <(String, HomeworkPayload)>[]
        : [
            for (final h
                in ref.watch(homeworkProvider).value ??
                    const <(String, HomeworkPayload)>[])
              if (hit([h.$2.title, h.$2.description])) h,
          ];
    final people = q.length < 2
        ? const <(String, PersonPayload)>[]
        : [
            for (final p
                in ref.watch(peopleProvider).value ??
                    const <(String, PersonPayload)>[])
              if (hit([p.$2.name, p.$2.label, p.$2.notes])) p,
          ];
    final nothing =
        q.length >= 2 &&
        events.isEmpty &&
        recipes.isEmpty &&
        todos.isEmpty &&
        homework.isEmpty &&
        people.isEmpty;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView(
        children: [
          if (nothing)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.searchNothing),
            ),
          if (events.isNotEmpty) header(l10n.searchEvents),
          for (final (id, e) in events.take(20))
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(e.title),
              subtitle: Text(
                [?e.location, ?e.notes?.split('\n').first].join(' · '),
              ),
              onTap: () => context.push(EventDetailScreen.pathFor(id)),
            ),
          if (recipes.isNotEmpty) header(l10n.recipes),
          for (final (id, r) in recipes)
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(r.title),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => RecipeScreen(id: id)),
              ),
            ),
          if (todos.isNotEmpty) header(l10n.searchTodos),
          for (final (id, a) in todos)
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: Text(a.title),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ActionSheet(id: id, ref: ref),
              ),
            ),
          if (homework.isNotEmpty) header(l10n.searchHomework),
          for (final (_, h) in homework)
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(h.title),
              onTap: () =>
                  context.go('${MoreScreen.path}/${HomeworkScreen.segment}'),
            ),
          if (people.isNotEmpty) header(l10n.searchPeople),
          for (final (id, p) in people)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(p.label ?? p.name),
              subtitle: p.notes == null ? null : Text(p.notes!),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WishlistScreen(personId: id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
