import 'package:flutter/material.dart';

import '../../common/l10n.dart';
import '../../shell/placeholder_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  static const path = '/chat';

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: context.l10n.tabChat,
      description: context.l10n.chatDescription,
    );
  }
}
