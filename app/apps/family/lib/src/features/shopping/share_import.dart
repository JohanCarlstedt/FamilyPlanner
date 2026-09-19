import 'dart:async';

import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../integrations/linked_calendars_screen.dart';
import 'recipes_screen.dart';

/// A link shared to the app from another one (spec §11 "share-sheet
/// import"): a recipe page, or a calendar feed. It is fetched on this
/// phone, as every other import is, so the server never sees it.
class ShareImport extends ConsumerStatefulWidget {
  const ShareImport({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareImport> createState() => _ShareImportState();
}

class _ShareImportState extends ConsumerState<ShareImport> {
  StreamSubscription<List<SharedMediaFile>>? _incoming;
  var _handling = false;

  @override
  void initState() {
    super.initState();
    try {
      _incoming = ReceiveSharingIntent.instance.getMediaStream().listen(
        _handle,
        onError: (Object e) => debugPrint('Shared link ignored: $e'),
      );
      // What was shared while the app was closed.
      ReceiveSharingIntent.instance.getInitialMedia().then(_handle);
    } on Object catch (e) {
      debugPrint('Sharing not available: $e');
    }
  }

  @override
  void dispose() {
    _incoming?.cancel();
    super.dispose();
  }

  Future<void> _handle(List<SharedMediaFile> shared) async {
    if (_handling || shared.isEmpty || !mounted) return;
    final link = _firstLink(shared);
    ReceiveSharingIntent.instance.reset();
    if (link == null) return;
    _handling = true;
    try {
      // A feed is a calendar; anything else worth keeping is a recipe.
      if (feedUrl(link) != null) {
        await openCalendarLink(context, ref, initialUrl: link);
      } else if (mounted) {
        await importRecipe(context, url: link);
      }
    } finally {
      _handling = false;
    }
  }

  static String? _firstLink(List<SharedMediaFile> shared) {
    for (final item in shared) {
      final text = item.path.trim();
      final match = RegExp(r'https?://\S+').firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
