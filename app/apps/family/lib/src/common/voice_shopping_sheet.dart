import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'l10n.dart';

/// Opened from the app icon's "Add to shopping list" (Android): listening
/// straight away, the words split into items as they come ("mjölk, ägg
/// och bröd" is three), editable, and added only when confirmed. Returns
/// the items, or null.
///
/// The phone's own dictation, as everywhere in the app
/// (common/dictation.dart): on-device where the phone has it, nothing
/// recorded or kept, nothing sent to the family's server.
Future<List<String>?> showVoiceShoppingSheet(BuildContext context) =>
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VoiceShoppingSheet(),
    );

class _VoiceShoppingSheet extends StatefulWidget {
  const _VoiceShoppingSheet();

  @override
  State<_VoiceShoppingSheet> createState() => _VoiceShoppingSheetState();
}

class _VoiceShoppingSheetState extends State<_VoiceShoppingSheet> {
  final _speech = SpeechToText();
  final _text = TextEditingController();
  var _listening = false;
  bool? _available;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    final ready = _available ?? await _speech.initialize();
    if (!mounted) return;
    setState(() => _available = ready);
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dictationUnavailable)),
      );
      return;
    }
    final before = _text.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords;
        if (spoken.isEmpty) return;
        final text = before.isEmpty ? spoken : '$before, $spoken';
        _text
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
      listenOptions: SpeechListenOptions(
        onDevice: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = spokenItems(_text.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🛒 ${l10n.voiceShoppingTitle}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: _listening ? theme.colorScheme.error : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _listening ? l10n.voiceShoppingListening : '',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final item in items) Chip(label: Text(item))],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _listening ? null : _listen,
                icon: const Icon(Icons.mic),
                label: Text(l10n.voiceShoppingAgain),
              ),
              const Spacer(),
              FilledButton(
                onPressed: items.isEmpty
                    ? null
                    : () => Navigator.pop(context, items),
                child: Text(l10n.voiceShoppingAdd(items.length)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
