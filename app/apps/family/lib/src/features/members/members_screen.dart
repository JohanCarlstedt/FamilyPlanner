import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/family_api_provider.dart';
import '../../common/l10n.dart';
import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';
import '../people/celebrations_screen.dart';
import 'diet_screen.dart';
import 'member_export.dart';

/// Who's in the family (spec §9). Children come first in onboarding and
/// needn't have a phone: a child entered here is on the calendar, in events
/// and routed reminders, and later claims a device without moving any data.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  static const segment = 'members';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final isParent = ref.watch(membershipProvider).value?.isParent ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.members)),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              onPressed: () => editMember(context, ref),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: Text(l10n.addChild),
            )
          : null,
      body: ListView(
        children: [
          for (final (i, m) in members.indexed)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: MemberStyle.colorOf(m, i),
                child: Text(
                  MemberStyle.initialsFor(members)[m.id] ?? '',
                  style: TextStyle(
                    color: MemberStyle.onColor(MemberStyle.colorOf(m, i)),
                  ),
                ),
              ),
              title: Text(m.displayName),
              subtitle: Text(
                ref.watch(custodyProvider).any((c) => c.coParentId == m.id)
                    ? l10n.roleCoParent
                    : _roleText(l10n, m),
              ),
              trailing: isParent
                  ? Builder(
                      builder: (button) => IconButton(
                        tooltip: l10n.exportMemberData(m.displayName),
                        icon: const Icon(Icons.ios_share),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(button);
                          try {
                            await shareMemberExport(button, ref, m);
                          } on Object catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.exportFailed('$e'))),
                            );
                          }
                        },
                      ),
                    )
                  : null,
              onTap: isParent
                  ? () => editMember(context, ref, member: m)
                  : null,
            ),
          if (isParent) ..._former(context, ref),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.childNoPhoneNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Members who've left and whose data isn't erased yet: exportable, and
  /// erasable (spec §9 per-member deletion).
  List<Widget> _former(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final former = ref.watch(formerMembersProvider).value ?? const [];
    if (former.isEmpty) return const [];
    return [
      const Divider(height: 32),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.formerMembers,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final m in former)
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
          title: Text(m.displayName),
          subtitle: Text(_roleText(l10n, m)),
          trailing: Builder(
            builder: (button) => PopupMenuButton<bool>(
              onSelected: (erase) => erase
                  ? _erase(context, ref, m)
                  : shareMemberExport(button, ref, m),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: false,
                  child: Text(l10n.exportMemberData(m.displayName)),
                ),
                PopupMenuItem(
                  value: true,
                  child: Text(l10n.eraseMemberData(m.displayName)),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  static Future<void> _erase(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.eraseMemberTitle(member.displayName)),
        content: Text(l10n.eraseMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.erase),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await ref.read(familyStoreProvider.future);
    await store.eraseMember(member.id);
    await ref.read(syncControllerProvider.notifier).syncNow();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.memberErased(member.displayName))),
    );
  }

  static String _roleText(AppLocalizations l10n, Member m) =>
      switch ((m.role, m.tier)) {
        (MemberRole.parent, _) => l10n.roleParent,
        (MemberRole.child, final tier?) => tierName(l10n, tier),
        (MemberRole.child, null) => l10n.roleChild,
        (MemberRole.helper, _) when m.isRelative => l10n.roleRelative,
        (MemberRole.helper, _) => l10n.roleHelper,
      };
}

String tierName(AppLocalizations l10n, MaturityTier tier) => switch (tier) {
  MaturityTier.little => l10n.tierLittle,
  MaturityTier.kid => l10n.tierKid,
  MaturityTier.teen => l10n.tierTeen,
};

/// Adds a child (no device needed), or edits a member's name, colour and,
/// for a child, age group.
Future<void> editMember(
  BuildContext context,
  WidgetRef ref, {
  Member? member,
}) => showDialog<void>(
  context: context,
  builder: (_) => _MemberDialog(member: member, ref: ref),
);

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({this.member, required this.ref});

  final Member? member;
  final WidgetRef ref;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _name = TextEditingController(text: widget.member?.displayName);
  late String? _color = widget.member?.color;
  late MaturityTier _tier = widget.member?.tier ?? MaturityTier.kid;
  String? _error;
  var _saving = false;

  bool get _isChild => widget.member?.isChild ?? true;

  Future<void> _removeFromFamily(Member member) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeMemberTitle(member.displayName)),
        content: Text(l10n.removeMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final ref = widget.ref;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final membership = (await ref.read(membershipProvider.future))!;
      final updated = await ref
          .read(pairingServiceProvider)
          .removeMember(
            membership: membership,
            device: await ref.read(deviceProvider.future),
            keyring: await ref.read(keyringProvider.future),
            memberId: member.id,
            members: await ref.read(membersProvider.future),
          );
      await ref.read(membershipProvider.notifier).save(updated);
      final store = await ref.read(familyStoreProvider.future);
      final existing = await store.payloadOf(member.id);
      await store.saveProfile(
        member.id,
        MemberProfile.write(
          existing: existing,
          displayName: member.displayName,
          role: member.role,
          color: member.color,
          tier: member.tier,
          endedAt: DateTime.now().toUtc(),
        ),
      );
      await store.rewrapToLatest();
      await ref.read(syncControllerProvider.notifier).syncNow();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.memberRemoved(member.displayName))),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.nameRequired);
      return;
    }
    setState(() => _saving = true);
    final ref = widget.ref;
    try {
      final store = await ref.read(familyStoreProvider.future);
      final members = await ref.read(membersProvider.future);
      var id = widget.member?.id;
      if (id == null) {
        final membership = (await ref.read(membershipProvider.future))!;
        id = await ref
            .read(familyApiProvider)
            .createMember(
              asDevice: membership.deviceId,
              role: MemberRole.child,
            );
      }
      final existing = await store.payloadOf(id);
      await store.saveProfile(
        id,
        MemberProfile.write(
          existing: existing,
          displayName: name,
          role: widget.member?.role ?? MemberRole.child,
          color:
              _color ??
              MemberStyle.palette[members.length % MemberStyle.palette.length],
          tier: _isChild ? _tier : null,
        ),
      );
      ref.read(syncControllerProvider.notifier).syncNow();
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.member == null ? l10n.addChild : l10n.editMember),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.member == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.memberName,
                errorText: _error,
              ),
            ),
            if (_isChild) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<MaturityTier>(
                initialValue: _tier,
                decoration: InputDecoration(labelText: l10n.tier),
                items: [
                  for (final t in MaturityTier.values)
                    DropdownMenuItem(value: t, child: Text(tierName(l10n, t))),
                ],
                onChanged: (t) => setState(() => _tier = t ?? _tier),
              ),
            ],
            if (widget.member case final m?) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context)..pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => DietScreen(member: m),
                    ),
                  );
                },
                icon: const Icon(Icons.no_food_outlined),
                label: Text(
                  l10n.foodAndAllergies(
                    (widget.ref.watch(dietNotesProvider).value ??
                            const <DietNote>[])
                        .where((n) => n.memberId == m.id)
                        .length,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  final ref = widget.ref;
                  final existing =
                      (ref.read(peopleProvider).value ??
                              const <(String, PersonPayload)>[])
                          .where((p) => p.$2.memberId == m.id)
                          .firstOrNull;
                  Navigator.pop(context);
                  editPerson(
                    context,
                    ref,
                    id: existing?.$1,
                    person: existing?.$2,
                    member: m,
                  );
                },
                icon: const Icon(Icons.cake_outlined),
                label: Text(l10n.memberBirthday),
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.colour, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final hex in MemberStyle.palette)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = hex),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(
                        0xFF000000 | int.parse(hex.substring(1), radix: 16),
                      ),
                      child: _color == hex
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (widget.member case final m?
            when m.id != widget.ref.read(membershipProvider).value?.memberId)
          TextButton(
            onPressed: _saving ? null : () => _removeFromFamily(m),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.removeMember),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
