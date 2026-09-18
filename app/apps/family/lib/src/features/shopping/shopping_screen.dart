import 'package:flutter/material.dart';

import '../../common/l10n.dart';
import '../../shell/placeholder_screen.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  static const path = '/shopping';

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: context.l10n.tabShopping,
      description: context.l10n.shoppingDescription,
    );
  }
}
