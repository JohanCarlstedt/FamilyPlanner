import 'package:flutter/material.dart';

import '../../common/l10n.dart';
import '../../shell/placeholder_screen.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  static const path = '/kitchen';

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: context.l10n.kitchenDisplay,
      description: context.l10n.kitchenDescription,
    );
  }
}
