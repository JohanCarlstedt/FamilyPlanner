import 'package:flutter/material.dart';

import 'l10n.dart';

/// Closes a dialog or sheet without saving anything: the plain way out of
/// every form, beside its Save. A dialog that could only be left by
/// tapping beside it, or a sheet only by swiping it away, was a way out
/// nobody could see.
class CancelButton extends StatelessWidget {
  const CancelButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => Navigator.pop(context),
    child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
  );
}

/// Asks before throwing away what was changed in a full-screen form.
/// True to leave without saving.
Future<bool> confirmDiscard(BuildContext context) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.discardTitle),
          content: Text(l10n.discardBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.discardKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.discardYes),
            ),
          ],
        ),
      ) ??
      false;
}

/// A full-screen form that can be left: a close button for a way out, and
/// a question before leaving when [changed] says something would be lost,
/// whether by the close button, the back button or the back gesture.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.changed, required this.child});

  /// Whether anything in the form differs from what it opened with.
  final bool Function() changed;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (!changed() || await confirmDiscard(context)) navigator.pop(result);
    },
    child: child,
  );
}
