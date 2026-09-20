import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'l10n.dart';

/// A microphone beside a text field, for the people who find typing hard.
///
/// Built for a seven-year-old asking whether he can sleep over: holding a
/// button and talking is a thing a child can do, and a keyboard often is
/// not.
///
/// **Where the voice goes.** This uses the phone's own dictation, not
/// anything of ours — no audio ever reaches the family's server, which
/// could not read it anyway. On-device recognition is asked for, so on a
/// phone that has it the words never leave the handset at all; on one that
/// does not, the platform falls back to its own service (Google's or
/// Apple's) exactly as the keyboard's dictation key already does. Nothing
/// is recorded or kept: the words go straight into the field, where they
/// can be edited or thrown away.
class DictationButton extends StatefulWidget {
  const DictationButton({super.key, required this.controller});

  /// The field the words land in.
  final TextEditingController controller;

  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  final _speech = SpeechToText();

  /// Null until the phone has been asked whether it can do this at all.
  bool? _available;
  var _listening = false;

  /// What the field held before this went on, so partial results replace
  /// each other instead of piling up.
  var _before = '';

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final ready = _available ?? await _speech.initialize();
    if (!mounted) return;
    setState(() => _available = ready);
    if (!ready) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.dictationUnavailable)));
      return;
    }

    _before = widget.controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords;
        if (spoken.isEmpty) return;
        final text = _before.isEmpty ? spoken : '$_before $spoken';
        widget.controller
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
      listenOptions: SpeechListenOptions(
        // Asked for, not required: a phone without it falls back to the
        // platform's own service, as the keyboard's dictation key does.
        onDevice: true,
        // A child pauses mid-sentence while thinking; ending on the first
        // silence cuts them off halfway.
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return IconButton(
      tooltip: _listening ? l10n.dictationStop : l10n.dictationStart,
      onPressed: _toggle,
      isSelected: _listening,
      icon: Icon(
        _listening ? Icons.mic : Icons.mic_none,
        color: _listening ? theme.colorScheme.error : null,
      ),
    );
  }
}
