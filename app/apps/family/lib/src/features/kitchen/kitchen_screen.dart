import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  static const path = '/kitchen';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Kitchen display',
      description: "The week, today's meal and the shopping list on a wall-mounted tablet. A device session: no member login and no chat keys.",
    );
  }
}
