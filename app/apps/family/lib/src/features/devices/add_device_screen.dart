import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  _Step _step = _Step.choose;
  String? _error;

  Future<void> _onScanned(String code) async {
    if (_step != _Step.scan) return;
    if (!code.startsWith('FAM1:')) {
      setState(() => _error = "That isn't a Family pairing code.");
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
      final updated = await ref
          .read(pairingServiceProvider)
          .addDevice(
            membership: membership,
            device: device,
            keyring: keyring,
            code: code,
            forWhom: _forWhom,
          );
      await ref.read(membershipProvider.notifier).save(updated);
      if (mounted) setState(() => _step = _Step.done);
    } on CryptoException {
      if (mounted) {
        setState(() {
          _step = _Step.scan;
          _error =
              "That code couldn't be read. Ask for a fresh one and scan again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.scan;
          _error =
              "Couldn't add the device. Check the connection and scan again.\n$e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a device')),
      body: SafeArea(
        child: switch (_step) {
          _Step.choose => _Choose(
            forWhom: _forWhom,
            onChanged: (v) => setState(() => _forWhom = v),
            onNext: () => setState(() => _step = _Step.scan),
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
    required this.onChanged,
    required this.onNext,
  });

  final NewDeviceFor forWhom;
  final ValueChanged<NewDeviceFor> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Who is the new device for?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<NewDeviceFor>(
          groupValue: forWhom,
          onChanged: (v) => onChanged(v!),
          child: const Column(
            children: [
              RadioListTile(
                value: NewDeviceFor.newChild,
                title: Text('A child'),
                subtitle: Text(
                  'Sees the family calendar and lists, not parents-only things.',
                ),
              ),
              RadioListTile(
                value: NewDeviceFor.otherParent,
                title: Text('The other parent'),
                subtitle: Text('Sees everything you see, and can add devices.'),
              ),
              RadioListTile(
                value: NewDeviceFor.myself,
                title: Text('Me, on another device'),
                subtitle: Text('A tablet or second phone of your own.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'On the new device, open Family and choose "Join my family" to show '
          'its code.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan the code'),
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
                      ? 'Family needs the camera to scan the code. Allow it in '
                            'Settings, then come back.'
                      : "The camera couldn't start: ${error.errorCode.name}",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.error ?? 'Point the camera at the code on the new device.',
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
            Text('Device added', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'It will finish setting up on its own in a moment.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onClose, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
