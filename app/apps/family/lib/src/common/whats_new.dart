import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_providers.dart';
import 'l10n.dart';

/// Shows what changed, once, the first time the app opens after an
/// update: the release notes of every build since this device last saw
/// them (assets/whats_new.json, written by tool/whats_new.py).
///
/// TestFlight's email goes out before a build's notes can be attached to
/// it, and nobody reads the TestFlight app; this is where they are read.
class WhatsNew extends ConsumerStatefulWidget {
  const WhatsNew({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WhatsNew> createState() => _WhatsNewState();
}

class _WhatsNewState extends ConsumerState<WhatsNew> {
  static const _seenKey = 'whatsNew.seenBuild';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    // Widget tests pump the whole shell and would find the sheet over
    // every screen they look at.
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final data = jsonDecode(
        await rootBundle.loadString('assets/whats_new.json'),
      ) as Map<String, dynamic>;
      final build = data['build'] as int;
      final prefs = await ref.read(devicePreferencesProvider.future);
      final seen = int.tryParse(await prefs.read(_seenKey) ?? '');
      if (seen != null && seen >= build) return;
      await prefs.write(_seenKey, '$build');
      if (!mounted) return;
      final language = Localizations.localeOf(context).languageCode;
      final notes = <(int, String)>[
        for (final MapEntry(key: n, value: text)
            in (data['notes'] as Map<String, dynamic>).entries)
          // Everything since last time; on a phone that has never kept
          // track, only this build's.
          if (int.tryParse(n) case final number?
              when number <= build &&
                  (seen == null ? number == build : number > seen))
            if (_inLanguage(text as Map<String, dynamic>, language)
                case final line?)
              (number, line),
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      if (notes.isEmpty || !mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _WhatsNewSheet(notes: notes),
      );
    } on Object catch (e) {
      // Never in the way: without its notes the app is just the app.
      debugPrint("What's new not shown: $e");
    }
  }

  static String? _inLanguage(Map<String, dynamic> text, String language) =>
      (text[language == 'sv' ? 'sv' : 'en-GB'] ?? text['en-GB']) as String?;

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.notes});

  final List<(int, String)> notes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '✨ ${l10n.whatsNewTitle}',
                style: theme.textTheme.titleLarge,
              ),
              for (final (build, text) in notes) ...[
                const SizedBox(height: 16),
                if (notes.length > 1)
                  Text(
                    l10n.whatsNewBuild(build),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.whatsNewOk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
