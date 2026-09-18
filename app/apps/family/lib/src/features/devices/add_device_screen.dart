import 'package:domain/domain.dart';

import '../../common/l10n.dart';

import 'package:family_crypto/family_crypto.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  _Step _step = _Step.choose;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _needsName => _forWhom != NewDeviceFor.myself;

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
            role: _forWhom == NewDeviceFor.newChild
                ? MemberRole.child
                : MemberRole.parent,
            color: MemberStyle
                .palette[members.length % MemberStyle.palette.length],
          ),
        );
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
            onChanged: (v) => setState(() => _forWhom = v),
            onNext: () {
              if (_needsName && _name.text.trim().isEmpty) {
                setState(() => _error = context.l10n.nameRequired);
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
    required this.onChanged,
    required this.onNext,
    required this.error,
  });

  final NewDeviceFor forWhom;
  final TextEditingController name;
  final ValueChanged<NewDeviceFor> onChanged;
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
            ],
          ),
        ),
        if (forWhom != NewDeviceFor.myself) ...[
          const SizedBox(height: 8),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: forWhom == NewDeviceFor.newChild
                  ? l10n.childsName
                  : l10n.otherParentsName,
              border: const OutlineInputBorder(),
              errorText: error,
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
