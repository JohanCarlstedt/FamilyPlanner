import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const path = '/more';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'More',
      description:
          "Planner, celebrations, meals, actions, map and family settings.",
    );
  }
}
