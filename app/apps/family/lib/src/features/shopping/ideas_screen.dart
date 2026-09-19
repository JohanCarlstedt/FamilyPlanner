import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../chat/chat_providers.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../membership/permissions_provider.dart';
import '../events/occurrence_editing.dart';
import '../members/diet_screen.dart';
import 'menu_screen.dart';
import 'shopping_providers.dart';

final suggestionsProvider =
    StreamProvider<List<(String, MealSuggestionPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchSuggestions();
    });

final pollsProvider = StreamProvider<List<(String, MealPollPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchPolls();
});

final votesProvider = StreamProvider<List<(String, MealVotePayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchVotes();
});

/// Spec §4: meal ideas anyone can put forward, and polls that settle a
/// dinner by approval voting. The tally stays hidden until the poll closes;
/// who has voted doesn't.
class IdeasScreen extends ConsumerWidget {
  const IdeasScreen({super.key});

  static const segment = 'ideas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final now = DateTime.now().toUtc();
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final recipes = <String, String>{
      for (final (id, r)
          in ref.watch(recipesProvider).value ??
              const <(String, RecipePayload)>[])
        id: r.title,
    };
    String optionName(String? recipeId, String? title) =>
        recipes[recipeId] ?? title ?? '—';
    final suggestions = [
      for (final s
          in ref.watch(suggestionsProvider).value ??
              const <(String, MealSuggestionPayload)>[])
        if (s.$2.openAt(now)) s,
    ];
    final polls =
        [
          for (final p
              in ref.watch(pollsProvider).value ??
                  const <(String, MealPollPayload)>[])
            if (p.$2.state == PollState.open ||
                (p.$2.closedAt?.isAfter(
                      now.subtract(const Duration(days: 14)),
                    ) ??
                    false))
              p,
        ]..sort((a, b) {
          final open = (a.$2.state == PollState.open ? 0 : 1).compareTo(
            b.$2.state == PollState.open ? 0 : 1,
          );
          return open != 0
              ? open
              : (a.$2.date ?? now).compareTo(b.$2.date ?? now);
        });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ideas)),
      floatingActionButton: permissions.shop
          ? FloatingActionButton.extended(
              onPressed: () => _suggest(context, ref),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(l10n.suggestMeal),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (permissions.planMenu)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => _startPoll(context, ref, suggestions),
                icon: const Icon(Icons.how_to_vote_outlined),
                label: Text(l10n.startPoll),
              ),
            ),
          if (polls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.polls, style: theme.textTheme.titleMedium),
            for (final (id, poll) in polls)
              _PollCard(
                id: id,
                poll: poll,
                names: names,
                optionName: optionName,
              ),
          ],
          const SizedBox(height: 16),
          Text(l10n.suggestions, style: theme.textTheme.titleMedium),
          if (suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.noSuggestions,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (id, s) in suggestions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(optionName(s.recipeId, s.title)),
              subtitle: Text(l10n.suggestedBy(names[s.suggestedBy] ?? '—')),
              trailing: permissions.planMenu
                  ? PopupMenuButton<bool>(
                      onSelected: (put) => put
                          ? _putOnMenu(context, ref, id, s)
                          : _decline(ref, id, s),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: true, child: Text(l10n.putOnMenu)),
                        PopupMenuItem(value: false, child: Text(l10n.decline)),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  static Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final picked = await pickRecipe(context, ref);
    if (picked == null) return;
    final me = ref.read(membershipProvider).value?.memberId;
    if (me == null) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.saveSuggestion(
      MealSuggestionPayload.write(
        suggestedBy: me,
        recipeId: picked.$1,
        title: picked.$2,
        expiresAt: DateTime.now().toUtc().add(MealSuggestionPayload.lifetime),
      ),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static Future<void> _decline(
    WidgetRef ref,
    String id,
    MealSuggestionPayload s,
  ) async {
    final store = await ref.read(familyStoreProvider.future);
    await store.saveSuggestion(s.withState(SuggestionState.declined), id: id);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static Future<DateTime?> _pickDay(BuildContext context) async {
    final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
    final day = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    return day == null ? null : DateTime.utc(day.year, day.month, day.day);
  }

  static Future<void> _putOnMenu(
    BuildContext context,
    WidgetRef ref,
    String id,
    MealSuggestionPayload s,
  ) async {
    final day = await _pickDay(context);
    if (day == null) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.saveMeal(
      MealPayload.write(
        date: day,
        title: s.recipeId == null ? s.title : null,
        servings: ref.read(membersProvider).value?.length,
        recipes: [if (s.recipeId case final r?) MealRecipe(recipeId: r)],
      ),
    );
    await store.saveSuggestion(s.withState(SuggestionState.scheduled), id: id);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static Future<void> _startPoll(
    BuildContext context,
    WidgetRef ref,
    List<(String, MealSuggestionPayload)> suggestions,
  ) async {
    final l10n = context.l10n;
    final day = await _pickDay(context);
    if (day == null || !context.mounted) return;
    final me = ref.read(membershipProvider).value?.memberId ?? '';
    final recipes =
        ref.read(recipesProvider).value ?? const <(String, RecipePayload)>[];
    final candidates = <MealPollOption>[
      for (final (id, s) in suggestions)
        MealPollOption(
          id: 's:$id',
          proposer: s.suggestedBy,
          recipeId: s.recipeId,
          title: s.title,
          suggestionId: id,
        ),
      for (final (id, _) in recipes)
        if (!suggestions.any((s) => s.$2.recipeId == id))
          MealPollOption(id: 'r:$id', proposer: me, recipeId: id),
    ];
    final titles = {for (final (id, r) in recipes) id: r.title};
    final byId = {for (final (id, r) in recipes) id: r};
    final notes = ref.read(dietNotesProvider).value ?? const <DietNote>[];
    final names = {
      for (final m in ref.read(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    // Spec §4 "Dietary exclusions beat votes": a strict conflict can't be
    // an option, and says why it isn't.
    final leftOut = <String>[];
    final allowed = <MealPollOption>[];
    for (final o in candidates) {
      final recipe = byId[o.recipeId];
      final strict = recipe == null
          ? const <DietConflict>[]
          : dietConflicts(
              recipe.ingredients,
              notes,
              IngredientCatalogue.swedish,
            ).where((c) => c.note.strict).toList();
      if (strict.isEmpty) {
        allowed.add(o);
      } else {
        leftOut.add(
          l10n.dietLeftOut(
            titles[o.recipeId] ?? '—',
            names[strict.first.note.memberId] ?? '—',
            dietTypeName(l10n, strict.first.note.type),
          ),
        );
      }
    }
    if (!context.mounted) return;
    final chosen = await showDialog<List<MealPollOption>>(
      context: context,
      builder: (_) => _OptionsDialog(
        options: allowed,
        leftOut: leftOut,
        label: (o) => titles[o.recipeId] ?? o.title ?? '—',
      ),
    );
    if (chosen == null || chosen.length < 2) return;
    final location = tz.getLocation(familyTimeZone);
    final now = tz.TZDateTime.now(location);
    // The evening before, so there's time to shop; soon, if that's gone.
    var closes = tz.TZDateTime(location, day.year, day.month, day.day - 1, 18);
    if (closes.isBefore(now.add(const Duration(hours: 1)))) {
      closes = now.add(const Duration(hours: 2));
    }
    final title = DateFormat('EEEE d MMMM').format(day);
    final members = ref.read(membersProvider).value ?? const <Member>[];
    final store = await ref.read(familyStoreProvider.future);
    await store.savePoll(
      MealPollPayload.write(
        title: title,
        date: day,
        closesAt: closes.toUtc(),
        options: chosen,
        createdBy: me,
        eligible: [
          for (final m in members)
            if (m.role != MemberRole.helper) m.id,
        ],
      ),
    );
    ref.read(syncControllerProvider.notifier).syncNow();
    // Where the family already talks (spec §4 "Polls render in the family
    // chat").
    try {
      final chat = await ref.read(familyChatProvider.future);
      if (chat.hasThread) await chat.send(l10n.pollChat(title));
    } on Object catch (e) {
      debugPrint('Poll note to chat failed: $e');
    }
  }
}

class _OptionsDialog extends StatefulWidget {
  const _OptionsDialog({
    required this.options,
    required this.label,
    this.leftOut = const [],
  });

  final List<MealPollOption> options;
  final List<String> leftOut;
  final String Function(MealPollOption) label;

  @override
  State<_OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<_OptionsDialog> {
  final _chosen = <MealPollOption>[];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pollOptions),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in widget.options)
              CheckboxListTile(
                value: _chosen.contains(o),
                onChanged: !_chosen.contains(o) && _chosen.length >= 5
                    ? null
                    : (on) => setState(
                        () => on! ? _chosen.add(o) : _chosen.remove(o),
                      ),
                title: Text(widget.label(o)),
              ),
            for (final line in widget.leftOut)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _chosen.length < 2
              ? null
              : () => Navigator.pop(context, _chosen),
          child: Text(l10n.startPoll),
        ),
      ],
    );
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({
    required this.id,
    required this.poll,
    required this.names,
    required this.optionName,
  });

  final String id;
  final MealPollPayload poll;
  final Map<String, String> names;
  final String Function(String?, String?) optionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final me = ref.watch(membershipProvider).value?.memberId;
    final votes = [
      for (final (_, v)
          in ref.watch(votesProvider).value ??
              const <(String, MealVotePayload)>[])
        if (v.pollId == id && v.options.isNotEmpty) v,
    ];
    final mine = votes.where((v) => v.memberId == me).firstOrNull?.options;
    final open = poll.state == PollState.open;
    final mayVote = open && poll.eligible.contains(me);
    final permissions = ref.watch(permissionsProvider);
    String label(String? optionId) {
      final o = poll.options.where((o) => o.id == optionId).firstOrNull;
      return o == null ? '—' : optionName(o.recipeId, o.title);
    }

    Future<void> close({String? override}) async {
      final store = await ref.read(familyStoreProvider.future);
      await store.closePoll(id, override: override, overriddenBy: me);
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.title, style: theme.textTheme.titleSmall),
            if (open) ...[
              Text(
                l10n.pollCloses(
                  DateFormat('EEEE HH:mm').format(
                    wallClock(poll.closesAt ?? DateTime.now(), familyTimeZone),
                  ),
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (mayVote)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.pollTickHint),
                ),
              for (final o in poll.options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: mine?.contains(o.id) ?? false,
                  onChanged: !mayVote
                      ? null
                      : (on) async {
                          final ticks = {...?mine};
                          on! ? ticks.add(o.id) : ticks.remove(o.id);
                          final store = await ref.read(
                            familyStoreProvider.future,
                          );
                          await store.castVote(id, me!, ticks);
                          ref.read(syncControllerProvider.notifier).syncNow();
                        },
                  title: Text(optionName(o.recipeId, o.title)),
                ),
              Text(
                votes.isEmpty
                    ? l10n.pollNobodyVoted
                    : l10n.pollVoted(
                        votes.map((v) => names[v.memberId] ?? '—').join(', '),
                      ),
                style: theme.textTheme.bodySmall,
              ),
              if (permissions.planMenu)
                Row(
                  children: [
                    TextButton(onPressed: close, child: Text(l10n.closeNow)),
                    PopupMenuButton<String>(
                      onSelected: (o) => close(override: o),
                      itemBuilder: (_) => [
                        for (final o in poll.options)
                          PopupMenuItem(
                            value: o.id,
                            child: Text(optionName(o.recipeId, o.title)),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l10n.chooseInstead,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                poll.winner == null
                    ? l10n.pollNoVotes
                    : l10n.pollWon(label(poll.winner)),
                style: theme.textTheme.bodyLarge,
              ),
              if (poll.overriddenBy case final by?)
                Text(
                  l10n.pollOverridden(
                    names[by] ?? '—',
                    label(poll.votedWinner),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
