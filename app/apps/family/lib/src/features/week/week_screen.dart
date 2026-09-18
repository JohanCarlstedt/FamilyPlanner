import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  static const path = '/week';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Week',
      description: "A seven-column week grid with member filter chips and drag-to-reschedule.",
    );
  }
}
