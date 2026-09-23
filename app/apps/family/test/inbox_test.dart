import 'package:domain/domain.dart';
import 'package:family/src/features/inbox/inbox.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// What lands in a member's inbox, and in what order.
void main() {
  final now = DateTime.utc(2026, 9, 23, 18);
  const members = [
    Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent),
    Member(id: 'johan', displayName: 'Johan', role: MemberRole.parent),
    Member(id: 'tuva', displayName: 'Tuva', role: MemberRole.child),
  ];

  (String, ActionPayload) chore(
    String id, {
    String? doneBy,
    DateTime? doneAt,
    bool approval = false,
    ActionState state = ActionState.done,
    String? seenBy,
  }) {
    var a = ActionPayload.write(title: id, requiresApproval: approval);
    if (doneBy != null) {
      a = a.next(
        ActionStep(what: 'done', by: doneBy, at: doneAt ?? now),
        state: state,
        completedBy: doneBy,
        completedAt: doneAt ?? now.subtract(const Duration(hours: 1)),
        seenBy: seenBy,
        seenAt: seenBy == null ? null : now,
      );
    }
    return (id, a);
  }

  (String, HomeworkPayload) homework(
    String id, {
    String member = 'tuva',
    DateTime? finishedAt,
    String? seenBy,
  }) {
    var h = HomeworkPayload.write(
      memberId: member,
      title: id,
      dueAt: now.add(const Duration(days: 1)),
    ).withState(HomeworkState.done, at: finishedAt ?? now);
    if (seenBy != null) h = h.seen(seenBy, now);
    return (id, h);
  }

  List<InboxItem> inbox({
    String me = 'anna',
    bool isParent = true,
    List<(String, ActionPayload)> actions = const [],
    List<(String, HomeworkPayload)> hw = const [],
    int unread = 0,
  }) => inboxFor(
    me: me,
    isParent: isParent,
    members: members,
    actions: actions,
    homework: hw,
    pollsAwaiting: const [],
    unreadMessages: unread,
    now: now,
  );

  test("a child's finished homework and chores wait for a parent", () {
    final items = inbox(
      actions: [chore('Mata katten', doneBy: 'tuva')],
      hw: [homework('Glosor')],
    );
    expect(
      [for (final i in items) (i.kind, i.title, i.who)],
      [
        (InboxKind.homeworkDone, 'Glosor', 'tuva'),
        (InboxKind.choreDone, 'Mata katten', 'tuva'),
      ],
    );
  });

  test('seen, a parent\'s own, or long ago: not in the inbox', () {
    expect(
      inbox(
        actions: [
          chore('seen', doneBy: 'tuva', seenBy: 'johan'),
          chore('grown-up', doneBy: 'johan'),
          chore(
            'old',
            doneBy: 'tuva',
            doneAt: now.subtract(const Duration(days: 20)),
          ),
          chore('approved', doneBy: 'tuva', state: ActionState.approved),
        ],
        hw: [
          homework('seen', seenBy: 'anna'),
          homework('mine', member: 'johan'),
          homework('old', finishedAt: now.subtract(const Duration(days: 20))),
        ],
      ),
      isEmpty,
    );
  });

  test('a chore that asks for approval asks for approval, not a nod', () {
    final items = inbox(
      actions: [chore('Diska', doneBy: 'tuva', approval: true)],
    );
    expect([for (final i in items) i.kind], [InboxKind.approval]);
  });

  test('a child sees what is asked of them, never what parents check', () {
    final asked = ActionPayload.write(title: 'Städa').next(
      ActionStep(what: 'delegated', by: 'anna', to: 'tuva', at: now),
      delegation: const Delegation(from: 'anna', to: 'tuva'),
    );
    final items = inbox(
      me: 'tuva',
      isParent: false,
      actions: [
        ('s', asked),
        chore('Mata katten', doneBy: 'tuva'),
      ],
      hw: [homework('Glosor')],
      unread: 2,
    );
    expect([for (final i in items) i.kind], [InboxKind.chat, InboxKind.asked]);
    expect(items.first.count, 2);
  });

  test('what others wait on comes before what only needs a nod', () {
    final items = inbox(
      actions: [
        chore('Mata katten', doneBy: 'tuva'),
        chore('Diska', doneBy: 'tuva', approval: true),
      ],
      unread: 1,
    );
    expect(
      [for (final i in items) i.kind],
      [InboxKind.chat, InboxKind.approval, InboxKind.choreDone],
    );
  });
}
