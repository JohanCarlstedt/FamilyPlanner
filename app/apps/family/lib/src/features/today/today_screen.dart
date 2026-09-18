import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const path = '/today';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Today',
      description: "Today's timeline in each member's colour, with a warning strip for events that have no responsible adult.",
    );
  }
}
