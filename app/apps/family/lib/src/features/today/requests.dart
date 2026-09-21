import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/dictation.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';

final requestsProvider = StreamProvider<List<(String, RequestPayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchRequests();
});

/// "Can I…?" on Today (spec §10: a kid's request button). A child asks and
/// sees answers from the last few days; a parent sees what's waiting and
/// answers it there.
class RequestsCard extends ConsumerWidget {
  const RequestsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(membershipProvider).value;
    if (membership == null) return const SizedBox();
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final recent = DateTime.now().toUtc().subtract(const Duration(days: 3));
    final all =
        ref.watch(requestsProvider).value ?? const <(String, RequestPayload)>[];

    if (membership.isParent) {
      final waiting = [
        for (final r in all)
          if (r.$2.state == RequestState.pending) r,
      ];
      return Column(
        children: [
          for (final (id, r) in waiting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.asks(names[r.requestedBy] ?? '—'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(r.message),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _answer(context, ref, id, false),
                            child: Text(l10n.no),
                          ),
                          FilledButton(
                            onPressed: () => _answer(context, ref, id, true),
                            child: Text(l10n.yes),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final mine = [
      for (final r in all)
        if (r.$2.requestedBy == membership.memberId &&
            !r.$2.acknowledged &&
            (r.$2.state == RequestState.pending ||
                (r.$2.decidedAt?.isAfter(recent) ?? false)))
          r,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.question_answer_outlined),
              title: Text(l10n.canI),
              onTap: () => _ask(context, ref),
            ),
            for (final (id, r) in mine)
              // An answered one can be swiped away once it has been read.
              // A pending one cannot: it is still a question, and clearing
              // it would only hide it from the person waiting.
              _maybeDismissible(
                id: id,
                answered: r.state != RequestState.pending,
                onDismissed: () async {
                  final store = await ref.read(familyStoreProvider.future);
                  await store.acknowledgeRequest(id);
                  ref.read(syncControllerProvider.notifier).syncNow();
                },
                child: ListTile(
                dense: true,
                leading: Icon(switch (r.state) {
                  RequestState.pending => Icons.hourglass_empty,
                  RequestState.approved => Icons.check_circle,
                  RequestState.rejected => Icons.cancel,
                }),
                title: Text(r.message),
                subtitle: Text(
                  [
                    switch (r.state) {
                      RequestState.pending => l10n.waitingForAnswer,
                      RequestState.approved => l10n.answeredYes(
                        names[r.decidedBy] ?? '—',
                      ),
                      RequestState.rejected => l10n.answeredNo(
                        names[r.decidedBy] ?? '—',
                      ),
                    },
                    ?r.answer,
                  ].join(' · '),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// [child] as it is, or inside a swipe-to-clear when it has been
  /// answered. Swiping a question that is still waiting would hide it from
  /// the only person it helps.
  static Widget _maybeDismissible({
    required String id,
    required bool answered,
    required Future<void> Function() onDismissed,
    required Widget child,
  }) => answered
      ? Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          background: const ColoredBox(
            color: Colors.transparent,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.check),
              ),
            ),
          ),
          onDismissed: (_) => onDismissed(),
          child: child,
        )
      : child;

  static Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final text = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.canI),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.canIHint,
            // Asking out loud, for the children who cannot yet type a
            // sentence. It is the point of this box that a seven-year-old
            // can use it.
            suffixIcon: DictationButton(controller: text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: Text(l10n.askParents),
          ),
        ],
      ),
    );
    if (message == null || message.isEmpty) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.ask(message);
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  static Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool approved,
  ) async {
    final l10n = context.l10n;
    final text = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? l10n.yes : l10n.no),
        content: TextField(
          controller: text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.answerNote),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (note == null) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.answer(
      id,
      approved: approved,
      note: note.isEmpty ? null : note,
    );
    ref.read(syncControllerProvider.notifier).syncNow();
  }
}
