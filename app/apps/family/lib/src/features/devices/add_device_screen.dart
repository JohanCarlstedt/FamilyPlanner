import 'package:domain/domain.dart';

import '../../common/l10n.dart';

import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../common/member_style.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';

/// The parent's side of pairing (crypto doc §7): choose who the new device is
/// for, scan the code it shows, and admit it.
class AddDeviceScreen extends ConsumerStatefulWidget {
  const AddDeviceScreen({super.key});

  static const segment = 'add-device';

  @override
  ConsumerState<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

enum _Step { choose, scan, working, done }

class _AddDeviceScreenState extends ConsumerState<AddDeviceScreen> {
  NewDeviceFor _forWhom = NewDeviceFor.newChild;
  final _name = TextEditingController();

  /// For [NewDeviceFor.existing]: who the device joins.
  Member? _existing;

  /// For [NewDeviceFor.helper]: which children, until when. Tomorrow at noon
  /// by default: an evening's babysitting, and the next morning.
  final _helperChildren = <String>{};
  DateTime _helperUntil = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 12);
  }();
  _Step _step = _Step.choose;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// A new member gets a name here; an existing one already has one.
  bool get _needsName =>
      _forWhom == NewDeviceFor.newChild ||
      _forWhom == NewDeviceFor.otherParent ||
      _forWhom == NewDeviceFor.helper ||
      _forWhom == NewDeviceFor.coParent;

  Future<void> _onScanned(String code) async {
    if (_step != _Step.scan) return;
    if (!code.startsWith('FAM1:')) {
      setState(() => _error = context.l10n.notAPairingCode);
      return;
    }
    setState(() {
      _step = _Step.working;
      _error = null;
    });

    try {
      final membership = (await ref.read(membershipProvider.future))!;
      final device = await ref.read(deviceProvider.future);
      final keyring = await ref.read(keyringProvider.future);
      final (updated, memberId) = await ref
          .read(pairingServiceProvider)
          .addDevice(
            membership: membership,
            device: device,
            keyring: keyring,
            code: code,
            forWhom: _forWhom,
            existing: _existing,
            members: await ref.read(membersProvider.future),
          );
      await ref.read(membershipProvider.notifier).save(updated);
      if (_needsName) {
        // The new member's profile: the name the parent typed, and the next
        // colour in the palette.
        final members = await ref.read(membersProvider.future);
        final store = await ref.read(familyStoreProvider.future);
        await store.saveProfile(
          memberId,
          MemberProfile.write(
            displayName: _name.text.trim(),
            role: switch (_forWhom) {
              NewDeviceFor.newChild => MemberRole.child,
              NewDeviceFor.helper || NewDeviceFor.coParent => MemberRole.helper,
              _ => MemberRole.parent,
            },
            color: MemberStyle
                .palette[members.length % MemberStyle.palette.length],
          ),
        );
        if (_forWhom == NewDeviceFor.helper ||
            _forWhom == NewDeviceFor.coParent) {
          final coParent = _forWhom == NewDeviceFor.coParent;
          await store.saveHelperGrant(
            HelperGrantPayload.write(
              helperMemberId: memberId,
              childIds: _helperChildren.toList(),
              until: coParent ? null : _helperUntil.toUtc(),
              coParent: coParent,
            ),
          );
          // What's already there reaches them now, not on its next edit.
          await store.rewrapToLatest();
        }
        await ref.read(syncControllerProvider.notifier).syncNow();
      }
      if (mounted) setState(() => _step = _Step.done);
    } on CryptoException {
      if (mounted) {
        setState(() {
          _step = _Step.scan;
          _error = context.l10n.codeUnreadable;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.scan;
          _error = context.l10n.addDeviceFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addDevice)),
      body: SafeArea(
        child: switch (_step) {
          _Step.choose => _Choose(
            forWhom: _forWhom,
            name: _name,
            existing: _existing,
            members: ref.watch(membersProvider).value ?? const [],
            me: ref.watch(membershipProvider).value?.memberId,
            onChanged: (v) => setState(() => _forWhom = v),
            onExisting: (m) => setState(() => _existing = m),
            helperChildren: _helperChildren,
            helperUntil: _helperUntil,
            onHelperChild: (id, on) => setState(
              () => on ? _helperChildren.add(id) : _helperChildren.remove(id),
            ),
            onHelperUntil: (when) => setState(() => _helperUntil = when),
            onNext: () {
              if (_needsName && _name.text.trim().isEmpty) {
                setState(() => _error = context.l10n.nameRequired);
                return;
              }
              if (_forWhom == NewDeviceFor.existing && _existing == null) {
                setState(() => _error = context.l10n.memberRequired);
                return;
              }
              if ((_forWhom == NewDeviceFor.helper ||
                      _forWhom == NewDeviceFor.coParent) &&
                  _helperChildren.isEmpty) {
                setState(() => _error = context.l10n.helperChildrenRequired);
                return;
              }
              setState(() {
                _error = null;
                _step = _Step.scan;
              });
            },
            error: _error,
          ),
          _Step.scan => _Scan(error: _error, onCode: _onScanned),
          _Step.working => const Center(child: CircularProgressIndicator()),
          _Step.done => _Done(onClose: () => context.pop()),
        },
      ),
    );
  }
}

class _Choose extends StatelessWidget {
  const _Choose({
    required this.forWhom,
    required this.name,
    required this.existing,
    required this.members,
    required this.me,
    required this.onChanged,
    required this.onExisting,
    required this.helperChildren,
    required this.helperUntil,
    required this.onHelperChild,
    required this.onHelperUntil,
    required this.onNext,
    required this.error,
  });

  final Set<String> helperChildren;
  final DateTime helperUntil;
  final void Function(String id, bool on) onHelperChild;
  final ValueChanged<DateTime> onHelperUntil;

  final NewDeviceFor forWhom;
  final TextEditingController name;
  final Member? existing;
  final List<Member> members;
  final String? me;
  final ValueChanged<NewDeviceFor> onChanged;
  final ValueChanged<Member?> onExisting;
  final VoidCallback onNext;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.whoIsDeviceFor, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<NewDeviceFor>(
          groupValue: forWhom,
          onChanged: (v) => onChanged(v!),
          child: Column(
            children: [
              RadioListTile(
                value: NewDeviceFor.newChild,
                title: Text(l10n.forChild),
                subtitle: Text(l10n.forChildSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.otherParent,
                title: Text(l10n.forOtherParent),
                subtitle: Text(l10n.forOtherParentSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.myself,
                title: Text(l10n.forMyself),
                subtitle: Text(l10n.forMyselfSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.helper,
                title: Text(l10n.forHelper),
                subtitle: Text(l10n.forHelperSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.coParent,
                title: Text(l10n.forCoParent),
                subtitle: Text(l10n.forCoParentSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.existing,
                title: Text(l10n.forExisting),
                subtitle: Text(l10n.forExistingSubtitle),
              ),
              RadioListTile(
                value: NewDeviceFor.kitchen,
                title: Text(l10n.forKitchen),
                subtitle: Text(l10n.forKitchenSubtitle),
              ),
            ],
          ),
        ),
        if (forWhom == NewDeviceFor.existing) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: existing?.id,
            decoration: InputDecoration(
              labelText: l10n.chooseMember,
              border: const OutlineInputBorder(),
              errorText: error,
            ),
            items: [
              for (final m in members)
                if (m.id != me)
                  DropdownMenuItem(value: m.id, child: Text(m.displayName)),
            ],
            onChanged: (id) =>
                onExisting(members.where((m) => m.id == id).firstOrNull),
          ),
        ],
        if (forWhom == NewDeviceFor.newChild ||
            forWhom == NewDeviceFor.otherParent ||
            forWhom == NewDeviceFor.helper ||
            forWhom == NewDeviceFor.coParent) ...[
          const SizedBox(height: 8),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: switch (forWhom) {
                NewDeviceFor.newChild => l10n.childsName,
                NewDeviceFor.helper => l10n.helpersName,
                NewDeviceFor.coParent => l10n.coParentsName,
                _ => l10n.otherParentsName,
              },
              border: const OutlineInputBorder(),
              errorText: error,
            ),
          ),
        ],
        if (forWhom == NewDeviceFor.coParent) ...[
          const SizedBox(height: 16),
          Text(l10n.coParentChildren, style: theme.textTheme.titleSmall),
          for (final m in members)
            if (m.isChild)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: helperChildren.contains(m.id),
                title: Text(m.displayName),
                onChanged: (on) => onHelperChild(m.id, on ?? false),
              ),
        ],
        if (forWhom == NewDeviceFor.helper) ...[
          const SizedBox(height: 16),
          Text(l10n.helperChildren, style: theme.textTheme.titleSmall),
          for (final m in members)
            if (m.isChild)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: helperChildren.contains(m.id),
                title: Text(m.displayName),
                onChanged: (on) => onHelperChild(m.id, on ?? false),
              ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.timer_outlined),
            title: Text(
              l10n.helperUntil(
                DateFormat('EEEE d MMMM HH:mm').format(helperUntil),
              ),
            ),
            onTap: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: helperUntil,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (day == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(helperUntil),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (time == null) return;
              onHelperUntil(
                DateTime(day.year, day.month, day.day, time.hour, time.minute),
              );
            },
          ),
          Text(
            l10n.helperForwardOnly,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.showCodeInstructions, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l10n.scanCode),
        ),
      ],
    );
  }
}

class _Scan extends StatefulWidget {
  const _Scan({required this.error, required this.onCode});

  final String? error;
  final ValueChanged<String> onCode;

  @override
  State<_Scan> createState() => _ScanState();
}

class _ScanState extends State<_Scan> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes
                  .map((b) => b.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code != null) widget.onCode(code);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? context.l10n.cameraDenied
                      : context.l10n.cameraFailed(error.errorCode.name),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.error ?? context.l10n.pointCamera,
            style: widget.error == null
                ? theme.textTheme.bodyMedium
                : TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.deviceAdded,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.deviceAddedDetail, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onClose, child: Text(context.l10n.done)),
          ],
        ),
      ),
    );
  }
}
