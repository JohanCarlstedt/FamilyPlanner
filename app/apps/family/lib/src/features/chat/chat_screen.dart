import 'package:flutter/material.dart';

import '../../shell/placeholder_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  static const path = '/chat';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Chat',
      description: "The thread list, with the family thread pinned at the top. End-to-end encrypted with MLS.",
    );
  }
}
