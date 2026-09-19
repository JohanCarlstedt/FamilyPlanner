import 'dart:math';

import 'package:family_crypto/family_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/l10n.dart';
import '../../membership/membership.dart';
import '../../pairing/device_providers.dart';
import '../../pairing/pairing_service.dart';

/// Makes this member's recovery kit (crypto doc §7.3, spec §9 step 7): shows
/// twelve words, has them checked back from paper, then saves the kit. The
/// words exist only on screen and on the paper; nothing stores them.
class RecoveryKitFlow extends ConsumerStatefulWidget {
  const RecoveryKitFlow({super.key, required this.onDone, this.intro});

  /// Called once the kit is saved.
  final VoidCallback onDone;

  /// Replaces the standard introduction, e.g. after a recovery.
  final String? intro;

  @override
  ConsumerState<RecoveryKitFlow> createState() => _RecoveryKitFlowState();
}

enum _Step { intro, words, check, saving, done }

class _RecoveryKitFlowState extends ConsumerState<RecoveryKitFlow> {
  var _step = _Step.intro;
  List<String> _words = const [];
  late List<int> _asked;
  final _answers = [TextEditingController(), TextEditingController()];
  String? _error;

  @override
  void dispose() {
    for (final a in _answers) {
      a.dispose();
    }
    super.dispose();
  }

  void _show() {
    final words = recoveryWords().split(' ');
    final random = Random.secure();
    final first = random.nextInt(12);
    var second = random.nextInt(11);
    if (second >= first) second++;
    setState(() {
      _words = words;
      _asked = [first, second]..sort();
      _step = _Step.words;
    });
  }

  Future<void> _check() async {
    final ok = [
      for (final (i, a) in _answers.indexed)
        a.text.trim().toLowerCase() == _words[_asked[i]],
    ].every((b) => b);
    if (!ok) {
      setState(() => _error = context.l10n.wordsDontMatch);
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.saving;
    });
    try {
      final membership = (await ref.read(membershipProvider.future))!;
      final updated = await ref
          .read(pairingServiceProvider)
          .createRecoveryKit(
            membership: membership,
            device: await ref.read(deviceProvider.future),
            keyring: await ref.read(keyringProvider.future),
            words: _words.join(' '),
          );
      await ref.read(membershipProvider.notifier).save(updated);
      if (!mounted) return;
      setState(() {
        _words = const [];
        _step = _Step.done;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.check;
        _error = context.l10n.kitFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return switch (_step) {
      _Step.intro => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.key, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.recoveryKit, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            widget.intro ?? l10n.recoveryIntro,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _show, child: Text(l10n.showWords)),
        ],
      ),
      _Step.words => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.recoveryIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4,
            children: [
              for (final (i, w) in _words.indexed)
                Text(
                  '${i + 1}. $w',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _step = _Step.check),
            child: Text(l10n.wroteThemDown),
          ),
        ],
      ),
      _Step.check => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.checkWords, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final (i, position) in _asked.indexed) ...[
            TextField(
              controller: _answers[i],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.wordNumber(position + 1),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _step = _Step.words),
                child: Text(l10n.showWords),
              ),
              const Spacer(),
              FilledButton(onPressed: _check, child: Text(l10n.save)),
            ],
          ),
        ],
      ),
      _Step.saving => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.savingKit),
          ],
        ),
      ),
      _Step.done => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.check_circle, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.kitReady, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.onDone,
            child: Text(l10n.continueLabel),
          ),
        ],
      ),
    };
  }
}

/// More > Recovery words.
class RecoveryKitScreen extends StatelessWidget {
  const RecoveryKitScreen({super.key});

  static const segment = 'recovery-words';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.recoveryKit)),
    body: RecoveryKitFlow(onDone: () => Navigator.of(context).maybePop()),
  );
}

/// Where a pending retirement of the recovery kit's device is kept, so an
/// interrupted recovery finishes on the next start.
const retireKitPreference = 'recovery.retire';
