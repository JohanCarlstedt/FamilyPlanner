import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/l10n.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../integrations/school_lunch.dart';

/// Each child's school on Skolmaten, for their lunch on Today and in the
/// menu planner. A parent pastes the school's address; it is checked
/// against Skolmaten there and then.
class SchoolLunchScreen extends ConsumerStatefulWidget {
  const SchoolLunchScreen({super.key});

  @override
  ConsumerState<SchoolLunchScreen> createState() => _SchoolLunchScreenState();
}

class _SchoolLunchScreenState extends ConsumerState<SchoolLunchScreen> {
  final _fields = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String member, String? school) =>
      _fields.putIfAbsent(
        member,
        () => TextEditingController(
          text: school == null ? '' : 'skolmaten.se/$school',
        ),
      );

  Future<void> _save(FamilySettings settings, String member) async {
    final text = _fields[member]?.text ?? '';
    final school = skolmatenSchool(text);
    final schools = {...settings.lunchSchools};
    if (text.trim().isEmpty) {
      schools.remove(member);
    } else if (school != null) {
      schools[member] = school;
    } else {
      return;
    }
    final store = await ref.read(familyStoreProvider.future);
    await store.saveSettings(settings.copyWith(lunchSchools: schools));
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value;
    final children = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.isChild && m.isActive) m,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lunchTitle)),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.lunchSettingsHelp, style: theme.textTheme.bodyMedium),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.https('skolmaten.se'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.lunchOpenSite),
                  ),
                ),
                for (final child in children) ...[
                  const SizedBox(height: 16),
                  Text(child.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _field(
                      child.id,
                      settings.lunchSchools[child.id],
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.lunchAddress,
                      hintText: 'skolmaten.se/…',
                    ),
                    onSubmitted: (_) => _save(settings, child.id),
                    onTapOutside: (_) => _save(settings, child.id),
                  ),
                  if (settings.lunchSchools[child.id] case final school?)
                    _Found(school: school),
                ],
              ],
            ),
    );
  }
}

/// What Skolmaten says about [school]: a dish from this week, or that it
/// has nothing, so a wrong address is seen at once.
class _Found extends ConsumerWidget {
  const _Found({required this.school});

  final String school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: switch (ref.watch(schoolLunchProvider(school))) {
        AsyncValue(value: final week?) when week.isNotEmpty => Text(
          '🍽️ ${l10n.lunchFound(week.values.first.first)}',
          style: theme.textTheme.bodySmall,
        ),
        AsyncValue(value: _?) => Text(
          l10n.lunchFoundNoMenu,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _ => const LinearProgressIndicator(),
      },
    );
  }
}
