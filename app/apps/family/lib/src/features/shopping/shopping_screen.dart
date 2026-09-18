import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  static const path = '/shopping';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Shopping',
      description:
          "The active list grouped by aisle, with source chips on each item.",
    );
  }
}
