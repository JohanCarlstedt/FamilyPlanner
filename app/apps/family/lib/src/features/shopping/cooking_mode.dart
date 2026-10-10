import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../common/keep_screen_on.dart';
import '../../common/l10n.dart';

/// A recipe to cook from: big enough to read from the stove, the
/// ingredients for the portions chosen, each struck through once it is
/// in, and the screen kept on for as long as it is open.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({
    super.key,
    required this.title,
    required this.ingredients,
    required this.portions,
    this.notes,
  });

  final String title;

  /// The ingredients as they read for [portions].
  final List<String> ingredients;
  final int portions;
  final String? notes;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  /// The ingredients already in, by position.
  final _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final big = theme.textTheme.headlineSmall;
    return KeepScreenOn(
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(widget.title),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                Icon(
                  Icons.light_mode_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cookingModeOn,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.cookingIngredients} · '
              '${l10n.cookingPortions(widget.portions)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final (i, line) in widget.ingredients.indexed)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _done.contains(i) ? _done.remove(i) : _done.add(i),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _done.contains(i)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 30,
                        color: _done.contains(i)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          line,
                          style: big?.copyWith(
                            decoration: _done.contains(i)
                                ? TextDecoration.lineThrough
                                : null,
                            color: _done.contains(i)
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.notes case final notes?) ...[
              const Divider(height: 40),
              Text(notes, style: big),
            ],
            const SizedBox(height: 32),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: Text(l10n.cookingDone),
            ),
          ],
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
