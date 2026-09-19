import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_providers.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';

/// The family thread (spec §6), end-to-end encrypted with MLS: the server
/// relays what it can't read.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  static const path = '/chat';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  Timer? _poll;
  var _sending = false;

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
      await syncFamilyChat(ref.read);
      if (mounted) setState(() {});
    } catch (_) {
      // Offline: the next tick tries again.
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final chat = await ref.read(familyChatProvider.future);
      await chat.send(text);
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
    final messages = ref.watch(chatMessagesProvider).value ?? const [];
    final owners = ref.watch(deviceMembersProvider).value ?? const {};
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final byId = {for (final m in members) m.id: m};
    final index = {for (final (i, m) in members.indexed) m.id: i};
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;
    final ready = chat?.canTalk ?? false;
    final time = DateFormat('HH:mm');

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyThread)),
      body: Column(
        children: [
          Expanded(
            child: !ready
                ? notice(isParent ? l10n.chatAlone : l10n.chatWaiting)
                : messages.isEmpty
                ? notice(l10n.chatEmpty)
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[messages.length - 1 - i];
                      final member = byId[owners[m.sender]];
                      final color = member == null
                          ? theme.colorScheme.outline
                          : MemberStyle.colorOf(member, index[member.id]!);
                      return Align(
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
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!m.mine)
                                    Text(
                                      member?.displayName ?? l10n.someone,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: color),
                                    ),
                                  Text(m.text),
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
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: ready,
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
        ],
      ),
    );
  }
}
