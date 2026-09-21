import 'dart:async';
import 'dart:io';

import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:go_router/go_router.dart';

import '../homework/homework_screen.dart';
import '../homework/week_letter.dart';
import '../homework/week_letter_screen.dart';
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

  /// iOS has no plugin side here: the share extension leaves the link in
  /// the group the app shares with it and opens the app, which hands it
  /// over on this channel.
  static const _iosShare = MethodChannel('family/share');

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _iosShare.setMethodCallHandler((call) async {
        if (call.method == 'shared') await _takeIosLink();
      });
      // One left while the app was closed: after the first frame, so the
      // dialog it opens has a navigator to open into.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_takeIosLink()),
      );
      return;
    }
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
    if (shared.isEmpty) return;
    final document = _firstDocument(shared);
    final link = _firstLink(shared);
    ReceiveSharingIntent.instance.reset();
    // A document before a link: a week letter shared out of Word or Teams
    // carries both, and the file is the one with the homework in it.
    if (document != null) {
      await _document(document);
      return;
    }
    await _link(link);
  }

  /// A shared document: the school's week letter, the way it actually
  /// reaches a parent. The SharePoint link beside it is useless to us — it
  /// answers 401 to anyone outside the school's tenant — but the app that
  /// shared it was signed in, so the file itself arrives readable.
  Future<void> _document(String path) async {
    if (_handling || !mounted) return;
    _handling = true;
    try {
      context.go(
        Uri(
          path: '${HomeworkScreen.path}/${WeekLetterScreen.segment}',
          queryParameters: {'file': path},
        ).toString(),
      );
    } finally {
      _handling = false;
    }
  }

  /// The kinds a week letter arrives as — including a photograph of the
  /// whiteboard, which is read on this phone.
  static const _documents = [
    '.docx',
    '.txt',
    '.md',
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
  ];

  static String? _firstDocument(List<SharedMediaFile> shared) {
    for (final item in shared) {
      final path = item.path;
      if (_documents.any(path.toLowerCase().endsWith)) return path;
    }
    return null;
  }

  Future<void> _takeIosLink() async {
    try {
      final link = await _iosShare.invokeMethod<String>('take');
      debugPrint('Shared link: ${link ?? 'none waiting'}');
      await _link(link);
    } on Object catch (e) {
      debugPrint('Shared link not collected: $e');
    }
  }

  Future<void> _link(String? link) async {
    if (_handling || link == null || !mounted) return;
    _handling = true;
    try {
      // A feed is a calendar; anything else worth keeping is a recipe.
      if (feedUrl(link) != null) {
        await openCalendarLink(context, ref, initialUrl: link);
      } else if (WeekLetter.looksLikeDocument(link)) {
        // A school document's link needs a sign-in the app does not have.
        // Say so where it can be acted on, rather than failing at it as a
        // recipe, which is what used to happen.
        context.go(
          Uri(
            path: '${HomeworkScreen.path}/${WeekLetterScreen.segment}',
            queryParameters: {'link': link},
          ).toString(),
        );
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
