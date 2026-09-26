import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';

import '../../common/l10n.dart';

/// How much a chore grows the child's city: a parent can make a big job
/// count as two or three.
class WorthPicker extends StatelessWidget {
  const WorthPicker({super.key, required this.worth, required this.onChanged});

  final int worth;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.choreWorth),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [
            for (var n = 1; n <= maxWorth; n++)
              ButtonSegment(value: n, label: Text('$n×')),
          ],
          selected: {worth},
          onSelectionChanged: (v) => onChanged(v.single),
        ),
      ],
    ),
  );
}
