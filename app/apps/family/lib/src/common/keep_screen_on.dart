import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the phone's screen on for as long as [child] is shown, and gives
/// the screen back to the phone's own setting afterwards: for cooking
/// mode, where hands are floury and the recipe must not go dark.
/// (ios/Runner/AppDelegate.swift and MainActivity.kt, `family/screen`.)
class KeepScreenOn extends StatefulWidget {
  const KeepScreenOn({super.key, required this.child});

  final Widget child;

  @override
  State<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<KeepScreenOn> {
  static const _channel = MethodChannel('family/screen');

  @override
  void initState() {
    super.initState();
    _set(true);
  }

  @override
  void dispose() {
    _set(false);
    super.dispose();
  }

  static Future<void> _set(bool on) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } on MissingPluginException {
      // Widget tests and the desktop have no screen to keep on.
    } on PlatformException catch (e) {
      debugPrint('Keeping the screen on failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
