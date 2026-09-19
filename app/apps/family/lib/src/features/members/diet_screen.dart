import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/store_providers.dart';

/// Every current member's dietary notes, for whoever plans a meal.
final dietNotesProvider = StreamProvider<List<DietNote>>((ref) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchProfiles().map(
    (profiles) => [
      for (final (id, p) in profiles)
        if (p.endedAt == null) ...p.dietNotes(id),
    ],
  );
});

String dietTypeName(AppLocalizations l10n, DietType type) => switch (type) {
  DietType.allergy => l10n.dietAllergy,
  DietType.intolerance => l10n.dietIntolerance,
  DietType.dislike => l10n.dietDislike,
  DietType.diet => l10n.dietDiet,
};

/// What a note is about, as people read it: the catalogue's name where it
/// names an ingredient.
String dietValueName(String value) =>
    IngredientCatalogue.swedish.byKey(value)?.name ?? value;

/// A recipe's conflicts, one line each: "Maja: Allergy · 1 dl nötter".
List<String> describeConflicts(
  AppLocalizations l10n,
  List<DietConflict> conflicts,
  Map<String, String> names,
) => [
  for (final c in conflicts)
    l10n.dietConflict(
      names[c.note.memberId] ?? '—',
      dietTypeName(l10n, c.note.type),
      c.line,
    ),
];

/// One member's food notes (spec §4 `member_dietary_note`).
class DietScreen extends ConsumerWidget {
  const DietScreen({super.key, required this.member});

  final Member member;

  Future<void> _save(WidgetRef ref, List<DietNote> notes) async {
    final store = await ref.read(familyStoreProvider.future);
    final existing = await store.payloadOf(member.id);
    if (existing == null) return;
    await store.saveProfile(
      member.id,
      MemberProfile.read(existing).withDiet(notes),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = [
      for (final n in ref.watch(dietNotesProvider).value ?? const <DietNote>[])
        if (n.memberId == member.id) n,
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${member.displayName} · ${l10n.dietTitle}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final note = await showDialog<DietNote>(
            context: context,
            builder: (_) => _NoteDialog(memberId: member.id),
          );
          if (note != null) await _save(ref, [...notes, note]);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.dietAdd),
      ),
      body: ListView(
        children: [
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.dietEmpty),
            ),
          for (final n in notes)
            ListTile(
              leading: Icon(
                n.strict ? Icons.warning_amber : Icons.info_outline,
                color: n.strict ? Theme.of(context).colorScheme.error : null,
              ),
              title: Text(dietValueName(n.value)),
              subtitle: Text(
                [
                  dietTypeName(l10n, n.type),
                  if (n.strict) l10n.dietStrict,
                ].join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _save(ref, [
                  for (final x in notes)
                    if (x != n) x,
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.memberId});

  final String memberId;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _what = TextEditingController();
  var _type = DietType.allergy;
  var _strict = true;

  @override
  void dispose() {
    _what.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.dietAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DietType>(
            initialValue: _type,
            items: [
              for (final t in DietType.values)
                DropdownMenuItem(value: t, child: Text(dietTypeName(l10n, t))),
            ],
            onChanged: (t) => setState(() {
              _type = t ?? _type;
              // Allergies are strict to start with; a dislike isn't.
              _strict = _type == DietType.allergy;
            }),
          ),
          TextField(
            controller: _what,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.dietWhat,
              hintText: l10n.dietWhatHint,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _strict,
            onChanged: (v) => setState(() => _strict = v),
            title: Text(l10n.dietStrict),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            final what = _what.text.trim();
            if (what.isEmpty) return;
            // A known ingredient is stored as the ingredient, so every way
            // a recipe writes it is caught.
            final key = IngredientCatalogue.swedish.match(what)?.key;
            Navigator.pop(
              context,
              DietNote(
                memberId: widget.memberId,
                type: _type,
                value: key ?? what.toLowerCase(),
                strict: _strict,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// What in [recipe] runs into the family's notes.
List<DietConflict> recipeConflicts(WidgetRef ref, RecipePayload recipe) =>
    dietConflicts(
      recipe.ingredients,
      ref.watch(dietNotesProvider).value ?? const [],
      IngredientCatalogue.swedish,
    );

/// A small warning mark: red for a strict conflict, amber otherwise.
Widget? dietMark(BuildContext context, List<DietConflict> conflicts) {
  if (conflicts.isEmpty) return null;
  final strict = conflicts.any((c) => c.note.strict);
  return Icon(
    Icons.warning_amber,
    size: 18,
    color: strict ? Theme.of(context).colorScheme.error : Colors.amber.shade800,
  );
}
