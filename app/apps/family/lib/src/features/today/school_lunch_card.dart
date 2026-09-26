import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../integrations/school_lunch.dart';
import '../../membership/membership.dart';
import '../rewards/rewards_providers.dart' show familyDay;

/// Today's school lunch: a child sees their own, a parent each child's.
/// Nothing unless a school is set for someone and it has a menu today.
class SchoolLunchCard extends ConsumerWidget {
  const SchoolLunchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = familyDay(DateTime.now().toUtc());
    final lunches = ref.watch(lunchOnProvider(today)).value ?? const {};
    final me = ref.watch(membershipProvider).value;
    if (lunches.isEmpty || me == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final shown = me.isParent
        ? lunches
        : {
            for (final e in lunches.entries)
              if (e.key == me.memberId) e.key: e.value,
          };
    if (shown.isEmpty) return const SizedBox.shrink();
    // Children at the same school eat the same: said once, with both names.
    final bySchool = <String, List<String>>{};
    for (final MapEntry(key: who, value: dishes) in shown.entries) {
      (bySchool[dishes.join('\n')] ??= []).add(names[who] ?? '');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🍽️ ${l10n.lunchTitle}', style: theme.textTheme.titleSmall),
              for (final MapEntry(key: dishes, value: who) in bySchool.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    me.isParent
                        ? l10n.lunchFor(
                            who.join(', '),
                            dishes.split('\n').join(' · '),
                          )
                        : dishes.split('\n').join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
