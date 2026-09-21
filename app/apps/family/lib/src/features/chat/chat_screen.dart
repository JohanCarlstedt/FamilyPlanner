import 'dart:async';

import 'package:domain/domain.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_providers.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import '../../reminders/push.dart';

/// "Anna", "Anna and Erik", "Anna, Erik and Maja".
String _names(AppLocalizations l10n, List<String> names) => switch (names) {
  [] => '',
  [final one] => one,
  _ => l10n.nameList(names.sublist(0, names.length - 1).join(', '), names.last),
};

/// What a thread is called on this device: the family's, the other
/// person's name, or the group's.
String conversationName(
  AppLocalizations l10n,
  Conversation c,
  Map<String, Member> byId,
  String me,
) => switch (c.scope) {
  ConversationScope.family => l10n.familyThread,
  _ when c.title?.trim().isNotEmpty ?? false => c.title!.trim(),
  _ => _names(l10n, [
    for (final id in c.participants)
      if (id != me) byId[id]?.displayName ?? l10n.someone,
  ]),
};

/// Spec §6: "emoji-only messages rendered large — that last one is a
/// two-line rule and it's the detail people notice missing".
bool _emojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.characters.length > 8) return false;
  return !RegExp(r'[0-9A-Za-zÀ-ÿ]').hasMatch(trimmed) &&
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}]',
        unicode: true,
      ).hasMatch(trimmed);
}

/// The emoji people reach for first, before opening the whole picker.
const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Spec §6: the family thread first, then direct and group conversations,
/// every one end-to-end encrypted with MLS.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  static const path = '/chat';

  static String threadPath(String group) =>
      '$path/${ThreadScreen.segment}/$group';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await syncChat(ref.read);
    } catch (_) {
      // Offline: the next tick tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final conversations = ref.watch(conversationsProvider).value;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final index = {for (final (i, m) in members.indexed) m.id: i};
    final membership = ref.watch(membershipProvider).value;
    final me = membership?.memberId ?? '';
    final owners = ref.watch(deviceMembersProvider).value ?? const {};
    final canStart =
        byId[me] != null && members.any((m) => canMessage(byId[me]!, m));
    final time = DateFormat('HH:mm');
    final day = DateFormat.MMMd(l10n.localeName);

    String when(DateTime at) {
      final local = at.toLocal();
      final now = DateTime.now();
      return DateUtils.isSameDay(local, now)
          ? time.format(local)
          : day.format(local);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabChat)),
      floatingActionButton: canStart
          ? FloatingActionButton.extended(
              onPressed: () => _startNew(context),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.newConversation),
            )
          : null,
      body: conversations == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final c in conversations)
                    Builder(
                      builder: (context) {
                        final others = [
                          for (final id in c.participants)
                            if (id != me) ?byId[id],
                        ];
                        final last = c.last;
                        final lastSender = last == null
                            ? null
                            : last.mine
                            ? l10n.you
                            : byId[owners[last.sender]]?.displayName;
                        return ListTile(
                          leading: switch ((c.scope, others)) {
                            (ConversationScope.direct, [final other]) =>
                              CircleAvatar(
                                backgroundColor: MemberStyle.colorOf(
                                  other,
                                  index[other.id]!,
                                ),
                                foregroundColor: Colors.white,
                                child: Text(other.displayName.characters.first),
                              ),
                            (ConversationScope.family, _) => const CircleAvatar(
                              child: Icon(Icons.home_outlined),
                            ),
                            _ => const CircleAvatar(
                              child: Icon(Icons.groups_outlined),
                            ),
                          },
                          title: Text(
                            conversationName(l10n, c, byId, me),
                            style: c.unread > 0
                                ? const TextStyle(fontWeight: FontWeight.w600)
                                : null,
                          ),
                          subtitle: Text(
                            last == null
                                ? l10n.noMessagesYet
                                : last.kind == ChatMessageKind.readers
                                ? l10n.readersChanged
                                : lastSender == null
                                ? last.text
                                : '$lastSender: ${last.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (last != null)
                                Text(
                                  when(last.sentAt),
                                  style: theme.textTheme.labelSmall,
                                ),
                              if (c.unread > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Badge.count(count: c.unread),
                                ),
                            ],
                          ),
                          onTap: () =>
                              context.push(ChatScreen.threadPath(c.group)),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _startNew(BuildContext context) async {
    final group = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _NewConversationSheet(),
    );
    if (group != null && context.mounted) {
      await context.push(ChatScreen.threadPath(group));
    }
  }
}

/// Picks who to talk to; says before anything is sent who else will read.
class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<_NewConversationSheet> {
  final _picked = <String>{};
  final _title = TextEditingController();
  var _starting = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final group = await startConversation(
        ref.read,
        others: _picked.toList(),
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      );
      navigator.pop(group);
    } on StateError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.nobodyReachable)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sendFailed)));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final me = ref.watch(membershipProvider).value?.memberId;
    final settings =
        ref.watch(settingsProvider).value ?? FamilySettings.defaults;
    final withDevices = ref.watch(membersWithDevicesProvider).value;
    final byId = {for (final m in members) m.id: m};
    final index = {for (final (i, m) in members.indexed) m.id: i};
    final self = byId[me];
    final candidates = [
      if (self != null)
        for (final m in members)
          if (canMessage(self, m)) m,
    ];
    final audience = ConversationAudience.of(
      participants: {?me, ..._picked},
      members: members,
      settings: settings,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.newConversation,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in candidates)
                    Builder(
                      builder: (context) {
                        // No device, no keys (spec §6): nobody to deliver to.
                        final reachable =
                            withDevices == null || withDevices.contains(m.id);
                        return CheckboxListTile(
                          value: _picked.contains(m.id),
                          onChanged: reachable
                              ? (on) => setState(
                                  () => on!
                                      ? _picked.add(m.id)
                                      : _picked.remove(m.id),
                                )
                              : null,
                          secondary: CircleAvatar(
                            backgroundColor: MemberStyle.colorOf(
                              m,
                              index[m.id]!,
                            ),
                            foregroundColor: Colors.white,
                            child: Text(m.displayName.characters.first),
                          ),
                          title: Text(m.displayName),
                          subtitle: reachable ? null : Text(l10n.noDevice),
                        );
                      },
                    ),
                ],
              ),
            ),
            if (_picked.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.groupName,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            if (_picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _ReadersLine(
                  supervisors: [
                    for (final id in audience.supervisors)
                      byId[id]?.displayName ?? l10n.someone,
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _picked.isEmpty || _starting ? null : _start,
                child: Text(l10n.startConversation),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spec §6: the key list is the reader list, and the thread says so.
class _ReadersLine extends StatelessWidget {
  const _ReadersLine({required this.supervisors});

  final List<String> supervisors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final supervised = supervisors.isNotEmpty;
    return Row(
      children: [
        Icon(
          supervised ? Icons.visibility_outlined : Icons.lock_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            supervised
                ? l10n.alsoReadBy(_names(l10n, supervisors))
                : l10n.onlyParticipants,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// One thread, end-to-end encrypted with MLS: the server relays what it
/// can't read.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.group});

  static const segment = 'thread';

  final String group;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _text = TextEditingController();
  Timer? _poll;
  var _sending = false;
  var _showEmoji = false;

  @override
  void initState() {
    super.initState();
    // Pushes bring messages when the app is away; while the thread is open,
    // a short poll keeps it live.
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await syncChat(ref.read);
      final chat = await ref.read(familyChatProvider.future);
      await chat.markRead(widget.group);
      if (mounted) setState(() {});
    } catch (_) {
      // Offline: the next tick tries again.
    }
  }

  /// Puts an emoji on a message, or takes this device's member's own off
  /// again if it's already there.
  Future<void> _react(
    ChatMessage on,
    String emoji, {
    bool remove = false,
  }) async {
    try {
      final chat = await ref.read(familyChatProvider.future);
      await chat.react(
        group: widget.group,
        messageId: on.id,
        emoji: emoji,
        remove: remove,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.sendFailed)));
      }
    }
  }

  Future<void> _pickReaction(ChatMessage on, Set<String> mine) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                children: [
                  for (final emoji in _quickReactions)
                    IconButton(
                      iconSize: 32,
                      isSelected: mine.contains(emoji),
                      onPressed: () => Navigator.pop(context, emoji),
                      icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) =>
                    Navigator.pop(context, emoji.emoji),
                config: const Config(height: 280),
              ),
            ),
            // Only your own, and only on the long press you already make
            // to react — a delete sitting under every message is a delete
            // someone's thumb finds by accident.
            if (on.mine && on.kind == ChatMessageKind.text && !on.removed)
              ListTile(
                leading: const Icon(Icons.backspace_outlined),
                title: Text(context.l10n.withdrawMessage),
                onTap: () => Navigator.pop(context, _withdrawChoice),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    if (chosen == _withdrawChoice) {
      await _withdraw(on);
      return;
    }
    await _react(on, chosen, remove: mine.contains(chosen));
  }

  /// Marks the sheet's "take it back" choice apart from an emoji. No
  /// emoji is this string, so it cannot be confused with one.
  static const _withdrawChoice = '\u0000withdraw';

  Future<void> _withdraw(ChatMessage message) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.withdrawMessage),
        // Said plainly: this is not the same as it never having been
        // sent, and pretending otherwise would be a lie about something
        // that matters.
        content: Text(l10n.withdrawExplain),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.withdrawIt),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      final chat = await ref.read(familyChatProvider.future);
      await chat.withdraw(group: widget.group, messageId: message.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sendFailed)));
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final chat = await ref.read(familyChatProvider.future);
      await chat.send(text, group: widget.group);
      await chat.markRead(widget.group);
      _text.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.sendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chat = ref.watch(familyChatProvider).value;
    final all =
        ref.watch(threadProvider(widget.group)).value ?? const <ChatMessage>[];
    // Reactions are messages; they belong under the one they're on.
    final reactions = <String, Map<String, Set<String>>>{};
    for (final r in all) {
      if (r.kind != ChatMessageKind.reaction) continue;
      final on = reactions.putIfAbsent(r.reactionTo ?? '', () => {});
      final who = on.putIfAbsent(r.text, () => <String>{});
      if (r.removed) {
        who.remove(r.sender);
        if (who.isEmpty) on.remove(r.text);
      } else {
        who.add(r.sender);
      }
    }
    final messages = [
      for (final m in all)
        if (m.kind != ChatMessageKind.reaction) m,
    ];
    final conversation = ref
        .watch(conversationsProvider)
        .value
        ?.where((c) => c.group == widget.group)
        .firstOrNull;
    final owners = ref.watch(deviceMembersProvider).value ?? const {};
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final index = {for (final (i, m) in members.indexed) m.id: i};
    final membership = ref.watch(membershipProvider).value;
    final me = membership?.memberId ?? '';
    final isParent = membership?.isParent ?? false;
    final family = widget.group == chat?.familyGroup;
    final ready = chat?.canTalkIn(widget.group) ?? false;
    final time = DateFormat('HH:mm');

    // Who reads without talking, from the key list itself.
    final participants = conversation?.participants.toSet() ?? const {};
    final watchers = family || chat == null
        ? const <String>[]
        : ({
            for (final d in chat.readersOf(widget.group)) ?owners[d],
          }..removeAll(participants)).toList();

    Widget notice(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    String nameOf(String id) => byId[id]?.displayName ?? l10n.someone;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          conversation == null
              ? (family ? l10n.familyThread : '…')
              : conversationName(l10n, conversation, byId, me),
        ),
      ),
      body: Column(
        children: [
          if (!family && ready)
            Material(
              color: theme.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _ReadersLine(
                  supervisors: [for (final id in watchers) nameOf(id)],
                ),
              ),
            ),
          // Said above the history rather than instead of it, so the reason
          // the composer is dead is on screen without the conversation
          // being taken away to say it.
          if (!ready && messages.isNotEmpty)
            Material(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  !family
                      ? l10n.chatJoining
                      : isParent
                      ? l10n.chatAlone
                      : l10n.chatWaiting,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            // Not being able to talk here is not a reason to hide what was
            // already said. A device out of the group — dropped an epoch
            // ago, or still joining — holds messages it decrypted when it
            // was in, and hiding them behind "joining…" reads as the
            // conversation having lost them. The notice stands in only
            // when there is genuinely nothing to show; otherwise it sits
            // above the history, and sending is what stays disabled.
            child: messages.isEmpty
                ? notice(
                    !ready
                        ? (!family
                              ? l10n.chatJoining
                              : isParent
                              ? l10n.chatAlone
                              : l10n.chatWaiting)
                        : (family ? l10n.chatEmpty : l10n.chatEmptyPrivate),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[messages.length - 1 - i];
                      if (m.kind == ChatMessageKind.readers) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            m.members.isEmpty
                                ? l10n.readersNowOnly
                                : l10n.readersNowAlso(
                                    _names(l10n, [
                                      for (final id in m.members) nameOf(id),
                                    ]),
                                  ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final member = byId[owners[m.sender]];
                      final color = member == null
                          ? theme.colorScheme.outline
                          : MemberStyle.colorOf(member, index[member.id]!);
                      final mine = {
                        for (final MapEntry(key: emoji, value: who)
                            in (reactions[m.id] ??
                                    const <String, Set<String>>{})
                                .entries)
                          if (who.contains(membership?.deviceId)) emoji,
                      };
                      return GestureDetector(
                        onLongPress: () => _pickReaction(m, mine),
                        child: Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Card(
                              color: m.mine
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Container(
                                decoration: m.mine
                                    ? null
                                    : BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: color,
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!m.mine)
                                      Text(
                                        member?.displayName ?? l10n.someone,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(color: color),
                                      ),
                                    if (m.removed &&
                                        m.kind == ChatMessageKind.text)
                                      // Said, not hidden: a thread that
                                      // silently loses a line reads as
                                      // the app having lost it.
                                      Text(
                                        l10n.withdrawnHere,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      )
                                    else
                                      Text(
                                        m.text,
                                        style: _emojiOnly(m.text)
                                            ? const TextStyle(fontSize: 36)
                                            : null,
                                      ),
                                    if (reactions[m.id] case final on?
                                        when on.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Wrap(
                                          spacing: 6,
                                          children: [
                                            for (final MapEntry(
                                                  key: emoji,
                                                  value: who,
                                                )
                                                in on.entries)
                                              InkWell(
                                                onTap: () => _react(
                                                  m,
                                                  emoji,
                                                  remove: who.contains(
                                                    membership?.deviceId,
                                                  ),
                                                ),
                                                child: Chip(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  label: Text(
                                                    who.length > 1
                                                        ? '$emoji ${who.length}'
                                                        : emoji,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        time.format(m.sentAt.toLocal()),
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.emoji,
                    isSelected: _showEmoji,
                    onPressed: ready
                        ? () => setState(() {
                            _showEmoji = !_showEmoji;
                            if (_showEmoji) FocusScope.of(context).unfocus();
                          })
                        : null,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: ready,
                      onTap: () => setState(() => _showEmoji = false),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.chatHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.send,
                    onPressed: ready && !_sending ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
          // Plain Unicode in the message body (spec §6): no sticker system,
          // no shortcode table.
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _text,
                config: const Config(height: 280),
              ),
            ),
        ],
      ),
    );
  }
}
