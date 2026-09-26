import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import 'feedback_screen.dart';

/// This build's version, bundled with its release notes
/// (tool/whats_new.py).
final bundledNotesProvider = FutureProvider<Map<String, dynamic>>(
  (ref) async =>
      jsonDecode(await rootBundle.loadString('assets/whats_new.json'))
          as Map<String, dynamic>,
);

/// The app's version, what the last releases brought, and the way to the
/// feedback board.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const segment = 'about';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(bundledNotesProvider).value;
    final language = Localizations.localeOf(context).languageCode;
    final notes = <(int, String)>[
      for (final MapEntry(key: n, value: text)
          in ((data?['notes'] as Map<String, dynamic>?) ?? const {}).entries)
        if (int.tryParse(n) case final build?)
          if (((text as Map<String, dynamic>)[language == 'sv'
                      ? 'sv'
                      : 'en-GB'] ??
                  text['en-GB'])
              case final String line)
            (build, line),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: const Icon(Icons.family_restroom, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Family Planner', style: theme.textTheme.titleLarge),
                    if (data != null)
                      Text(
                        l10n.aboutVersion(
                          data['version'] as String? ?? '',
                          data['build'] as int? ?? 0,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(l10n.aboutFeedback),
              subtitle: Text(l10n.aboutFeedbackSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.aboutReleaseNotes, style: theme.textTheme.titleMedium),
          for (final (build, text) in notes) ...[
            const SizedBox(height: 12),
            Text(
              l10n.whatsNewBuild(build),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
