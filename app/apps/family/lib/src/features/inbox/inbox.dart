import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/chat_providers.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../actions/actions_providers.dart';
import '../actions/actions_screen.dart';
import '../chat/chat_screen.dart';
import '../homework/homework_due.dart' show homeworkIcon;
import '../homework/homework_screen.dart';
import '../more/more_screen.dart';
import '../polls/open_polls.dart';
import '../polls/polls_screen.dart';
import '../rewards/rewards_providers.dart'
    show rewardsOnProvider, tradesProvider;
import '../rewards/trade_sheet.dart';

enum InboxKind { chat, asked, approval, trade, poll, homeworkDone, choreDone }

/// One thing waiting for this member, wherever it lives in the app.
class InboxItem {
  const InboxItem({
    required this.kind,
    required this.id,
    this.title = '',
    this.who,
    this.at,
    this.count = 0,
    this.icon,
    this.give,
    this.get,
  });

  final InboxKind kind;

  /// The action, homework or poll it is about; empty for chat.
  final String id;
  final String title;

  /// The member who did or asked it.
  final String? who;
  final DateTime? at;

  /// Unread messages, for chat.
  final int count;

  /// Homework's own icon: a test looks like a test here too.
  final IconData? icon;

  /// For a trade: what is offered and what is asked for, "2 🪵".
  final String? give;
  final String? get;
}

/// How far back a finished chore or homework still asks to be seen.
/// Without a limit, the first day of this inbox would have been every
/// finished thing since the family started.
const inboxLookBack = Duration(days: 14);

/// A child finished it on their own word and no parent has noticed yet.
/// A chore that asks for approval is not here: approving is noticing.
bool choreNeedsSeeing(
  ActionPayload a,
  Map<String, Member> members, {
  required DateTime now,
}) =>
    a.state == ActionState.done &&
    !a.requiresApproval &&
    a.seenBy == null &&
    (members[a.completedBy]?.isChild ?? false) &&
    a.completedAt != null &&
    now.difference(a.completedAt!) < inboxLookBack;

bool homeworkNeedsSeeing(
  HomeworkPayload h,
  Map<String, Member> members, {
  required DateTime now,
}) =>
    h.finished &&
    h.seenBy == null &&
    (members[h.memberId]?.isChild ?? false) &&
    h.finishedAt != null &&
    now.difference(h.finishedAt!) < inboxLookBack;

/// Everything waiting for [me], most pressing first: what others are
/// waiting on (messages, requests, approvals, questions), then what a
/// child is waiting for a parent to notice, newest first.
List<InboxItem> inboxFor({
  required String? me,
  required bool isParent,
  required List<Member> members,
  required List<(String, ActionPayload)> actions,
  required List<(String, HomeworkPayload)> homework,
  required List<(String, MealPollPayload)> pollsAwaiting,
  required int unreadMessages,
  required DateTime now,
  List<(String, TradePayload)> trades = const [],
}) {
  if (me == null) return const [];
  final byId = {for (final m in members) m.id: m};
  final done = <InboxItem>[
    if (isParent) ...[
      for (final (id, h) in homework)
        if (homeworkNeedsSeeing(h, byId, now: now))
          InboxItem(
            kind: InboxKind.homeworkDone,
            id: id,
            title: h.title,
            who: h.memberId,
            at: h.finishedAt,
            icon: homeworkIcon(h),
          ),
      for (final (id, a) in actions)
        if (choreNeedsSeeing(a, byId, now: now))
          InboxItem(
            kind: InboxKind.choreDone,
            id: id,
            title: a.title,
            who: a.completedBy,
            at: a.completedAt,
          ),
    ],
  ]..sort((a, b) => b.at!.compareTo(a.at!));
  return [
    if (unreadMessages > 0)
      InboxItem(kind: InboxKind.chat, id: '', count: unreadMessages),
    for (final (id, a) in actions)
      if (a.delegation case final d? when d.to == me && a.isOpen)
        InboxItem(kind: InboxKind.asked, id: id, title: a.title, who: d.from),
    if (isParent)
      for (final (id, a) in actions)
        if (a.awaitingApproval)
          InboxItem(
            kind: InboxKind.approval,
            id: id,
            title: a.title,
            who: a.completedBy,
            at: a.completedAt,
          ),
    // A brother or sister waiting for a yes or no to a swap.
    for (final (id, t) in offersTo(me, trades))
      InboxItem(
        kind: InboxKind.trade,
        id: id,
        who: t.from,
        give: '${t.count} ${goodEmoji(t.give!)}',
        get: '${t.count} ${goodEmoji(t.get!)}',
      ),
    for (final (id, p) in pollsAwaiting)
      InboxItem(kind: InboxKind.poll, id: id, title: p.title),
    ...done,
  ];
}

final inboxProvider = Provider<List<InboxItem>>((ref) {
  final membership = ref.watch(membershipProvider).value;
  return inboxFor(
    me: membership?.memberId,
    isParent: membership?.isParent ?? false,
    members: ref.watch(membersProvider).value ?? const [],
    actions: ref.watch(actionsProvider).value ?? const [],
    homework: ref.watch(homeworkProvider).value ?? const [],
    pollsAwaiting: ref.watch(awaitingAnswerProvider),
    trades: ref.watch(rewardsOnProvider)
        ? ref.watch(tradesProvider).value ?? const []
        : const [],
    unreadMessages: [
      for (final c
          in ref.watch(conversationsProvider).value ?? const <Conversation>[])
        c.unread,
    ].fold<int>(0, (a, b) => a + b),
    now: DateTime.now().toUtc(),
  );
});

/// The inbox on the dashboard: everything waiting, each a tap from being
/// opened and, where it is only a nod, dealt with right here.
class InboxCard extends ConsumerWidget {
  const InboxCard({super.key});

  /// Rows shown before "See all": enough for an ordinary day, few enough
  /// that the day itself is still on screen.
  static const shown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Badge.count(
                count: items.length,
                child: const Icon(Icons.inbox_outlined),
              ),
              title: Text(l10n.todoInbox, style: theme.textTheme.titleMedium),
            ),
            for (final item in items.take(shown)) InboxRow(item: item),
            if (items.length > shown)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showInbox(context),
                  child: Text(l10n.inboxSeeAll(items.length)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The whole inbox, from "See all".
Future<void> showInbox(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final items = ref.watch(inboxProvider);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.inboxNothing),
              ),
            for (final item in items) InboxRow(item: item),
          ],
        ),
      );
    },
  ),
);

class InboxRow extends ConsumerWidget {
  const InboxRow({super.key, required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final who = names[item.who] ?? '—';

    Future<void> run(Future<void> Function(FamilyStore s) f) async {
      final store = await ref.read(familyStoreProvider.future);
      await f(store);
      ref.read(syncControllerProvider.notifier).syncNow();
    }

    void openAction() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ActionSheet(id: item.id, ref: ref),
    );

    final (icon, text, open, quick) = switch (item.kind) {
      InboxKind.chat => (
        Icons.chat_bubble_outline,
        l10n.inboxChat(item.count),
        () => context.go(ChatScreen.path),
        null,
      ),
      InboxKind.asked => (
        Icons.forward_to_inbox_outlined,
        l10n.inboxAsked(who, item.title),
        openAction,
        null,
      ),
      InboxKind.approval => (
        Icons.task_alt,
        l10n.inboxApproval(who, item.title),
        openAction,
        (l10n.todoApprove, () => run((s) => s.approveAction(item.id))),
      ),
      InboxKind.trade => (
        Icons.swap_horiz,
        l10n.inboxTrade(who, item.give ?? '', item.get ?? ''),
        () => showTradeSheet(context),
        null,
      ),
      InboxKind.poll => (
        Icons.how_to_vote_outlined,
        l10n.inboxPoll(item.title),
        () => context.go('${MoreScreen.path}/${PollsScreen.segment}'),
        null,
      ),
      InboxKind.homeworkDone => (
        item.icon ?? Icons.menu_book_outlined,
        l10n.inboxHomeworkDone(who, item.title),
        () => context.go(HomeworkScreen.path),
        (
          l10n.inboxSeen,
          () => run((s) async {
            final me = ref.read(membershipProvider).value?.memberId;
            if (me != null) await s.markHomeworkSeen(item.id, me);
          }),
        ),
      ),
      InboxKind.choreDone => (
        Icons.check_circle_outline,
        l10n.inboxChoreDone(who, item.title),
        openAction,
        (l10n.inboxSeen, () => run((s) => s.markActionSeen(item.id))),
      ),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: open,
      trailing: quick == null
          ? const Icon(Icons.chevron_right)
          : FilledButton.tonal(onPressed: quick.$2, child: Text(quick.$1)),
    );
  }
}
