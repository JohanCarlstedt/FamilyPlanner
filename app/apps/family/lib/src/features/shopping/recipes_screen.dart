import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';
import '../../data/family_repository.dart';
import '../members/diet_screen.dart';
import 'shopping_providers.dart';

/// The family's recipes (spec §4 `recipe`): imported from a recipe site or
/// written by hand, kept as ingredients plus a link to the method.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  static const segment = 'recipes';

  Future<void> _import(BuildContext context) => importRecipe(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recipes)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _import(context),
        icon: const Icon(Icons.link),
        label: Text(l10n.importRecipe),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.recipesEmpty,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, r) in recipes)
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(r.title),
              trailing: dietMark(context, recipeConflicts(ref, r)),
              subtitle: Text(
                [
                  if (r.servings case final n?) l10n.portionsCount(n),
                  if (r.minutes case final m?) l10n.recipeMinutes(m),
                  if (r.url case final u?) Uri.tryParse(u)?.host ?? '',
                ].join(' · '),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => RecipeScreen(id: id)),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.newRecipe),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipeEditScreen(title: l10n.newRecipe),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imports a recipe from a link: fetched on this phone, then checked before
/// it's kept. [url] starts it straight away, as when a link is pasted.
Future<void> importRecipe(BuildContext context, {String? url}) async {
  final l10n = context.l10n;
  final navigator = Navigator.of(context);
  final imported = await showDialog<(String, RecipeImport)>(
    context: context,
    builder: (context) => _ImportDialog(url: url),
  );
  if (imported == null) return;
  final (link, recipe) = imported;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => RecipeEditScreen(
        title: l10n.reviewRecipe,
        initial: RecipePayload.write(
          title: recipe.title,
          ingredients: recipe.ingredients,
          url: link,
          servings: recipe.servings,
          minutes: recipe.totalMinutes,
          imageUrl: recipe.imageUrl,
          tags: recipe.categories,
        ),
      ),
    ),
  );
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({this.url});

  /// A link to fetch straight away, as when one is pasted.
  final String? url;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  // The dialog's own: disposed with it, never while it's still closing.
  late final _url = TextEditingController(text: widget.url);
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final link = _url.text.trim();
    try {
      final recipe = await fetchRecipe(link);
      if (mounted) Navigator.pop(context, (link, recipe));
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.recipeFetchFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.importRecipe),
      content: TextField(
        controller: _url,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onSubmitted: (_) => _fetch(),
        decoration: InputDecoration(
          labelText: l10n.recipeLink,
          helperText: l10n.recipeLinkHint,
          errorText: _error,
          errorMaxLines: 4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _fetch,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.next),
        ),
      ],
    );
  }
}

/// Writing a recipe, or checking an import before it's kept (spec §4:
/// "import always lands in review"): each line shows how it was read, so a
/// wrong amount is caught here rather than on every list after.
class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({
    super.key,
    required this.title,
    this.id,
    this.initial,
  });

  final String title;
  final String? id;
  final RecipePayload? initial;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  late final _name = TextEditingController(text: widget.initial?.title);
  late final _servings = TextEditingController(
    text: '${widget.initial?.servings ?? 4}',
  );
  late final _lines = TextEditingController(
    text: widget.initial?.ingredients.join('\n'),
  );
  late final _notes = TextEditingController(text: widget.initial?.notes);
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _lines.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _lines.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> get _ingredients => [
    for (final l in _lines.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final store = await ref.read(familyStoreProvider.future);
    await store.saveRecipe(
      RecipePayload.write(
        existing: widget.initial?.payload,
        title: _name.text.trim(),
        ingredients: _ingredients,
        url: widget.initial?.url,
        servings: int.tryParse(_servings.text.trim()),
        minutes: widget.initial?.minutes,
        imageUrl: widget.initial?.imageUrl,
        tags: widget.initial?.tags ?? const [],
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      id: widget.id,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initial?.url != null) ...[
            Text(
              l10n.recipeReviewNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.recipeTitle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _servings,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.recipeServings),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lines,
            minLines: 4,
            maxLines: null,
            decoration: InputDecoration(
              labelText: l10n.recipeIngredients,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          for (final text in _ingredients) _ParsedLine(text: text),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.recipeNotes,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a line will go on the list: its amount and the ingredient it's
/// counted as, or a note that it stays as written.
class _ParsedLine extends StatelessWidget {
  const _ParsedLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = IngredientLine.parse(text);
    final line = ShoppingLine.fromIngredient(
      parsed,
      IngredientCatalogue.swedish,
    );
    final known = line.key != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            known ? Icons.check : Icons.help_outline,
            size: 16,
            color: known
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              known
                  ? line.describe()
                  : '${line.describe()} · ${context.l10n.notOnCatalogue}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// A recipe: its ingredients for as many portions as tonight needs, onto
/// the list or off it again.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  int? _portions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipe = (ref.watch(recipesProvider).value ?? const [])
        .where((r) => r.$1 == widget.id)
        .firstOrNull
        ?.$2;
    if (recipe == null) return const Scaffold();
    final portions = _portions ?? recipe.servings ?? 4;
    final factor = recipe.servings == null ? 1.0 : portions / recipe.servings!;
    final listId = ref.watch(currentListProvider).value;
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    final listName =
        lists.where((l) => l.$1 == listId).firstOrNull?.$2.name ??
        l10n.tabShopping;
    final onList = (ref.watch(shoppingItemsProvider).value ?? const []).any(
      (i) =>
          i.$2.listId == listId &&
          i.$2.state != ItemState.bought &&
          i.$2.sources.any((s) => s.id == widget.id),
    );
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipeEditScreen(
                  title: recipe.title,
                  id: widget.id,
                  initial: recipe,
                ),
              ),
            ),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () async {
                  final store = await ref.read(familyStoreProvider.future);
                  await store.delete(ObjectKind.recipe, widget.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.deleteRecipe),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (recipeConflicts(ref, recipe) case final conflicts
              when conflicts.isNotEmpty)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in describeConflicts(l10n, conflicts, {
                      for (final m
                          in ref.watch(membersProvider).value ??
                              const <Member>[])
                        m.id: m.displayName,
                    }))
                      Text(line),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Text(l10n.recipeServings, style: theme.textTheme.titleSmall),
              const Spacer(),
              IconButton(
                onPressed: portions > 1
                    ? () => setState(() => _portions = portions - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$portions', style: theme.textTheme.titleMedium),
              IconButton(
                onPressed: () => setState(() => _portions = portions + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(),
          for (final text in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(switch (IngredientLine.parse(text)) {
                // As the recipe wrote it, unless the portions changed.
                _ when factor == 1 => text,
                final l when l.quantity != null =>
                  '${describeAmount(l.quantity! * factor, l.unit, l.name)}'
                      '${l.note == null ? '' : ' (${l.note})'}',
                final l => l.text,
              }),
            ),
          if (recipe.notes case final notes?) ...[
            const Divider(height: 32),
            Text(notes),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(l10n.addToList(listName)),
            onPressed: () async {
              final store = await ref.read(familyStoreProvider.future);
              var target = listId;
              if (target == null) {
                target = await store.saveShoppingList(
                  ShoppingListPayload.write(name: l10n.shoppingDefaultList),
                );
                await ref.read(currentListProvider.notifier).choose(target);
              }
              await store.addRecipeToList(
                target,
                widget.id,
                recipe,
                servings: portions,
              );
              ref.read(syncControllerProvider.notifier).syncNow();
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.addedToList(listName))),
              );
            },
          ),
          if (onList && listId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.remove_shopping_cart_outlined),
              label: Text(l10n.removeFromList(listName)),
              onPressed: () async {
                final store = await ref.read(familyStoreProvider.future);
                await store.removeFromList(listId, widget.id);
                ref.read(syncControllerProvider.notifier).syncNow();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.removedFromList(listName))),
                );
              },
            ),
          ],
          if (recipe.url case final url?) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.openRecipeSite),
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
