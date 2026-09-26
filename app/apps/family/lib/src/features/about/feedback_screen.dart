import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/family_api_provider.dart';
import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../membership/membership.dart';
import 'about_screen.dart';

/// The feedback board: bug reports and ideas from everyone who uses the
/// app, most voted first. Posts are written to the developer and are not
/// end-to-end encrypted, which the form says.
final feedbackProvider = FutureProvider.autoDispose<List<FeedbackPost>>((
  ref,
) async {
  final me = await ref.watch(membershipProvider.future);
  if (me == null) return const [];
  return ref.read(familyApiProvider).feedback(asDevice: me.deviceId);
});

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  String? _kind;

  Future<void> _vote(FeedbackPost post, int value) async {
    final me = ref.read(membershipProvider).value;
    if (me == null) return;
    try {
      await ref
          .read(familyApiProvider)
          .voteFeedback(
            asDevice: me.deviceId,
            id: post.id,
            value: post.myVote == value ? 0 : value,
          );
      ref.invalidate(feedbackProvider);
    } on Object catch (e) {
      debugPrint('Vote failed: $e');
      _failed();
    }
  }

  Future<void> _remove(FeedbackPost post) async {
    final me = ref.read(membershipProvider).value;
    if (me == null) return;
    try {
      await ref
          .read(familyApiProvider)
          .deleteFeedback(asDevice: me.deviceId, id: post.id);
      ref.invalidate(feedbackProvider);
    } on Object catch (e) {
      debugPrint('Remove failed: $e');
      _failed();
    }
  }

  void _failed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.feedbackFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final posts = ref.watch(feedbackProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final sent = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _NewPost(),
          );
          if (sent ?? false) ref.invalidate(feedbackProvider);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.feedbackNew),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(feedbackProvider.future),
        child: switch (posts) {
          AsyncValue(value: final list?) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final (kind, label) in [
                    (null, '★'),
                    ('bug', '🐞 ${l10n.feedbackBug}'),
                    ('idea', '💡 ${l10n.feedbackIdea}'),
                    ('other', l10n.feedbackOther),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.feedbackEmpty, textAlign: TextAlign.center),
                ),
              for (final post in list)
                if (_kind == null || post.kind == _kind)
                  _PostCard(
                    post: post,
                    onVote: (v) => _vote(post, v),
                    onRemove: () => _remove(post),
                  ),
            ],
          ),
          AsyncValue(error: _?) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.feedbackFailed, textAlign: TextAlign.center),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onVote,
    required this.onRemove,
  });

  final FeedbackPost post;
  final ValueChanged<int> onVote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = switch (post.status) {
      'planned' => l10n.feedbackStatusPlanned,
      'done' => l10n.feedbackStatusDone,
      'declined' => l10n.feedbackStatusDeclined,
      _ => null,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onVote(1),
                  icon: Icon(
                    Icons.arrow_upward,
                    color: post.myVote == 1 ? theme.colorScheme.primary : null,
                  ),
                ),
                Text('${post.score}', style: theme.textTheme.titleMedium),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onVote(-1),
                  icon: Icon(
                    Icons.arrow_downward,
                    color: post.myVote == -1 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(switch (post.kind) {
                        'bug' => '🐞',
                        'idea' => '💡',
                        _ => '💬',
                      }, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (status != null)
                        Chip(
                          label: Text(status),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (post.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(post.body, style: theme.textTheme.bodyMedium),
                    ),
                  if (post.reply case final reply?)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.feedbackReply(reply),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            post.author ?? l10n.feedbackAnonymousName,
                            ?post.appVersion,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (post.mine)
                        TextButton(
                          onPressed: onRemove,
                          child: Text(l10n.feedbackRemove),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewPost extends ConsumerStatefulWidget {
  const _NewPost();

  @override
  ConsumerState<_NewPost> createState() => _NewPostState();
}

class _NewPostState extends ConsumerState<_NewPost> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _kind = 'idea';
  var _anonymous = false;
  var _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty || _sending) return;
    final me = ref.read(membershipProvider).value;
    if (me == null) return;
    setState(() => _sending = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = (ref.read(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == me.memberId)
        .firstOrNull
        ?.displayName;
    final notes = ref.read(bundledNotesProvider).value;
    try {
      await ref
          .read(familyApiProvider)
          .postFeedback(
            asDevice: me.deviceId,
            kind: _kind,
            title: title,
            body: _body.text.trim(),
            anonymous: _anonymous,
            authorName: name,
            appVersion: notes == null
                ? null
                : '${notes['version']} (${notes['build']})',
            platform: kIsWeb
                ? 'web'
                : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          );
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackSent)));
    } on Object catch (e) {
      debugPrint('Feedback not sent: $e');
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.feedbackNew, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'bug',
                    label: Text('🐞 ${l10n.feedbackBug}'),
                  ),
                  ButtonSegment(
                    value: 'idea',
                    label: Text('💡 ${l10n.feedbackIdea}'),
                  ),
                  ButtonSegment(
                    value: 'other',
                    label: Text(l10n.feedbackOther),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.single),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.feedbackPostTitle),
              ),
              TextField(
                controller: _body,
                maxLength: 4000,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.feedbackPostBody),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _anonymous,
                onChanged: (v) => setState(() => _anonymous = v),
                title: Text(l10n.feedbackAnonymous),
                subtitle: Text(l10n.feedbackAnonymousHelp),
              ),
              Text(
                l10n.feedbackNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: Text(l10n.feedbackSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
