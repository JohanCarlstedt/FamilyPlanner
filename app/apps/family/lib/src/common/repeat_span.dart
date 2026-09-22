import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// When a repeating thing starts, and whether it ever stops.
///
/// A weekly chore or a weekly homework arrangement used to begin today —
/// whatever today happened to be when somebody opened the dialog — and run
/// for ever. Neither half was ever asked about, so a term's glosor carried
/// on into the summer holiday, and editing a rota in November moved its
/// start to November.
///
/// Two answers are allowed and no others: it goes on for ever, or it runs
/// between two days. "Ends, but we never said when" is the state this
/// exists to remove.
class RepeatSpan {
  const RepeatSpan({required this.startsOn, this.until});

  /// The first day it can happen on, as a wall-clock date.
  final DateTime startsOn;

  /// The last day it can happen on, or null for "for ever".
  final DateTime? until;

  bool get isForever => until == null;

  /// Whether anything can ever come of it.
  ///
  /// An end before the start is a span with no days in it: the planner
  /// would dutifully produce nothing, and the person who set it would see
  /// a chore that simply never appeared and no reason why.
  bool get isUsable => until == null || !until!.isBefore(startsOn);

  RepeatSpan copyWith({DateTime? startsOn, DateTime? until, bool forever = false}) =>
      RepeatSpan(
        startsOn: startsOn ?? this.startsOn,
        until: forever ? null : (until ?? this.until),
      );
}

/// Asks the two questions, and only those two.
class RepeatSpanField extends StatelessWidget {
  const RepeatSpanField({
    super.key,
    required this.span,
    required this.onChanged,
  });

  final RepeatSpan span;
  final ValueChanged<RepeatSpan> onChanged;

  static final _date = DateFormat('EEE d MMM yyyy');

  Future<void> _pick(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required ValueChanged<DateTime> then,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 5),
    );
    if (picked != null) {
      then(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ends = span.until;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(l10n.repeatFrom),
          subtitle: Text(_date.format(span.startsOn)),
          onTap: () => _pick(
            context,
            initial: span.startsOn,
            first: DateTime(span.startsOn.year - 1),
            then: (d) => onChanged(RepeatSpan(startsOn: d, until: span.until)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.all_inclusive),
          title: Text(l10n.repeatForever),
          subtitle: Text(l10n.repeatForeverHelp),
          value: span.isForever,
          onChanged: (forever) => onChanged(
            RepeatSpan(
              startsOn: span.startsOn,
              // Somewhere to put a term's end without having to guess at
              // one: the end of this school term is more often than not
              // a few months out.
              until: forever
                  ? null
                  : DateTime.utc(
                      span.startsOn.year,
                      span.startsOn.month + 3,
                      span.startsOn.day,
                    ),
            ),
          ),
        ),
        if (ends != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(l10n.repeatUntil),
            subtitle: Text(
              _date.format(ends),
              style: span.isUsable
                  ? null
                  : TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => _pick(
              context,
              initial: ends.isBefore(span.startsOn) ? span.startsOn : ends,
              first: span.startsOn,
              then: (d) =>
                  onChanged(RepeatSpan(startsOn: span.startsOn, until: d)),
            ),
          ),
        if (!span.isUsable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.repeatEndsBeforeStart,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
