import 'package:flutter/widgets.dart';

/// Each tab's own navigator: re-tapping a tab closes whatever was opened
/// on top of it (a page, a sheet), not only the pages the router knows.
final tabNavigators = [
  for (var i = 0; i < 5; i++) GlobalKey<NavigatorState>(debugLabel: 'tab $i'),
];
