import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../membership/membership.dart';
import 'passwords_screen.dart' show credentialsProvider;
import 'vault_sheets.dart';
import 'vault_words.dart';

/// LastPass's security dashboard, as a family needs it: a score, and the
/// passwords that are weak, used in more than one place, or not changed
/// for a year, each a tap from being fixed. Worked out on the phone from
/// what it can already open; nothing is sent anywhere.
class SecurityCheckScreen extends ConsumerWidget {
  const SecurityCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saved =
        ref.watch(credentialsProvider).value ??
        const <(String, CredentialPayload)>[];
    final byId = {for (final (id, c) in saved) id: c};
    final check = securityCheck([
      for (final (id, c) in saved) c.entry(id),
    ], now: DateTime.now().toUtc());
    final colour = check.score >= 80
        ? const Color(0xFF2E9D57)
        : check.score >= 50
        ? const Color(0xFFE0A100)
        : const Color(0xFFD64545);
    final folders = {for (final (_, c) in saved) ?c.folder}.toList()..sort();

    Widget group(String title, IconData icon, VaultIssue issue) {
      final ids = check.withIssue(issue);
      if (ids.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  '$title (${ids.length})',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          for (final id in ids)
            if (byId[id] case final c?)
              ListTile(
                leading: VaultAvatar(item: c),
                title: Text(c.title),
                subtitle: Text(vaultSummary(l10n, c)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showVaultItem(
                  context,
                  id: id,
                  onEdit: () {
                    final me = ref.read(membershipProvider).value?.memberId;
                    if (me == null) return;
                    showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => VaultEditSheet(
                        id: id,
                        existing: c,
                        memberId: me,
                        folders: folders,
                        isParent:
                            ref.read(membershipProvider).value?.isParent ??
                            false,
                      ),
                    );
                  },
                ),
              ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultCheck)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),
          Center(
            child: SizedBox.square(
              dimension: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: check.score / 100,
                      strokeWidth: 10,
                      color: colour,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    l10n.vaultScore(check.score),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          if (check.issues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.vaultAllGood,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          group(l10n.vaultWeak, Icons.lock_open, VaultIssue.weak),
          group(l10n.vaultReused, Icons.copy_all, VaultIssue.reused),
          group(l10n.vaultOld, Icons.history, VaultIssue.old),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.vaultCheckHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
