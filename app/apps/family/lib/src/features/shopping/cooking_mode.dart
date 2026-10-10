import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/keep_screen_on.dart';
import '../../common/l10n.dart';
import 'shopping_providers.dart' show fetchRecipe;

/// A recipe to cook from: big enough to read from the stove, the screen
/// kept on for as long as it is open, and two pages to swipe between. The
/// ingredients for the portions chosen, each struck through once it is
/// in; and the steps, read from the recipe's page as the mode opens and
/// never kept (the method is the site's), each ticked off as it is done.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({
    super.key,
    required this.title,
    required this.ingredients,
    required this.portions,
    this.notes,
    this.url,
    this.fetchSteps,
  });

  final String title;

  /// The ingredients as they read for [portions].
  final List<String> ingredients;
  final int portions;
  final String? notes;

  /// The recipe's page, where its steps are read from.
  final String? url;

  /// How the steps are fetched; the recipe's page by default.
  final Future<List<String>> Function(String url)? fetchSteps;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  /// The ingredients already in, and the steps done, by position.
  final _done = <int>{};
  final _stepsDone = <int>{};
  late final Future<List<String>>? _steps = switch (widget.url) {
    final url? when url.isNotEmpty => (widget.fetchSteps ?? _fromPage)(url),
    _ => null,
  };

  static Future<List<String>> _fromPage(String url) async =>
      (await fetchRecipe(url)).steps;

  Widget _tick({
    required bool done,
    required String text,
    required VoidCallback onTap,
    String? label,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 30,
              color: done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(label, style: theme.textTheme.labelLarge),
                  Text(
                    text,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredients(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(
          l10n.cookingPortions(widget.portions),
          style: theme.textTheme.titleMedium,
        ),
        for (final (i, line) in widget.ingredients.indexed)
          _tick(
            done: _done.contains(i),
            text: line,
            onTap: () => setState(
              () => _done.contains(i) ? _done.remove(i) : _done.add(i),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.cookingSwipe,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ],
    );
  }

  Widget _stepsPage(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget withNotes(List<Widget> top) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        ...top,
        if (widget.notes case final notes?) ...[
          const Divider(height: 40),
          Text(notes, style: theme.textTheme.headlineSmall),
        ],
        if (widget.url case final url? when url.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openRecipeSite),
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ],
      ],
    );
    final steps = _steps;
    if (steps == null) {
      return withNotes([Text(l10n.cookingStepsNoLink)]);
    }
    return FutureBuilder<List<String>>(
      future: steps,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.cookingStepsLoading),
              ],
            ),
          );
        }
        final found = snapshot.data ?? const <String>[];
        if (found.isEmpty) return withNotes([Text(l10n.cookingStepsNone)]);
        return withNotes([
          Text(
            l10n.cookingStepsFrom,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final (i, step) in found.indexed)
            _tick(
              done: _stepsDone.contains(i),
              label: l10n.cookingStep(i + 1),
              text: step,
              onTap: () => setState(
                () => _stepsDone.contains(i)
                    ? _stepsDone.remove(i)
                    : _stepsDone.add(i),
              ),
            ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return KeepScreenOn(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(widget.title),
            bottom: TabBar(
              tabs: [
                Tab(text: l10n.cookingIngredients),
                Tab(text: l10n.cookingSteps),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.light_mode_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cookingModeOn,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [_ingredients(context), _stepsPage(context)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [text], an ingredient line as the recipe wrote it, for [factor] times
/// the portions: as written unless the portions changed.
String ingredientFor(String text, double factor) =>
    switch (IngredientLine.parse(text)) {
      _ when factor == 1 => text,
      final l when l.quantity != null =>
        '${describeAmount(l.quantity! * factor, l.unit, l.name)}'
            '${l.note == null ? '' : ' (${l.note})'}',
      final l => l.text,
    };
