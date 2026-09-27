import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/store_providers.dart';
import '../features/shopping/shopping_providers.dart';
import '../membership/membership.dart';
import 'l10n.dart';
import 'voice_shopping_sheet.dart';

/// What was said to the phone while the app was closed: items for the
/// shopping list and activities to log. Siri's intents run without the
/// app, so they write it down (ios/Runner/AppDelegate.swift, VoiceQueue),
/// as does anything on Android (MainActivity.kt, VoiceQueue), and this
/// does it when the app starts or comes back.
///
/// On Android it also answers the app icon's "Add to shopping list":
/// opened that way, it listens (voice_shopping_sheet.dart).
class VoiceInbox extends ConsumerStatefulWidget {
  const VoiceInbox({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VoiceInbox> createState() => _VoiceInboxState();
}

class _VoiceInboxState extends ConsumerState<VoiceInbox> {
  static const _channel = MethodChannel('family/voice');
  late final AppLifecycleListener _lifecycle;
  var _taking = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      // Already running when the shortcut was used.
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'listen') await _listen();
      });
    }
    _lifecycle = AppLifecycleListener(onResume: _take);
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid) || _taking) return;
    // Widget tests have no iOS side to ask.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _taking = true;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('take');
      final shopping = [
        for (final s in (raw?['voice.shopping'] as List<dynamic>? ?? const []))
          if ((s as String).trim().isNotEmpty) s.trim(),
      ];
      final activities = [
        for (final s in (raw?['voice.activity'] as List<dynamic>? ?? const []))
          if ((s as String).trim().isNotEmpty) s.trim(),
      ];
      if (Platform.isAndroid &&
          await _channel.invokeMethod<bool>('listenRequested') == true) {
        // Taken after the queue, in the finally below, so the sheet does
        // not hold the queue up.
        _listenNext = true;
      }
      if (shopping.isEmpty && activities.isEmpty) return;
      final store = await ref.read(familyStoreProvider.future);
      if (shopping.isNotEmpty) await _addShopping(store, shopping);
      final parent = ref.read(membershipProvider).value?.isParent ?? false;
      for (final activity in activities) {
        await store.logActivity(title: activity, needsApproval: !parent);
      }
      ref.read(syncControllerProvider.notifier).syncNow();
    } on Object catch (e) {
      // Left in the queue on the iOS side only until taken: taken is
      // cleared there, so a failure here loses it. Said, not hidden.
      debugPrint('Voice queue not handled: $e');
    } finally {
      _taking = false;
      if (_listenNext) {
        _listenNext = false;
        await _listen();
      }
    }
  }

  var _listenNext = false;

  /// Listens for what to buy and adds it, once confirmed.
  Future<void> _listen() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final items = await showVoiceShoppingSheet(context);
    if (items == null || items.isEmpty) return;
    final store = await ref.read(familyStoreProvider.future);
    await _addShopping(store, items);
    ref.read(syncControllerProvider.notifier).syncNow();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.voiceShoppingAdded(items.length))),
    );
  }

  Future<void> _addShopping(FamilyStore store, List<String> shopping) async {
    final listId = await _listId(store);
    await store.addToList(
      listId,
      [
        for (final text in shopping)
          ShoppingLine.fromIngredient(
            IngredientLine.parse(text),
            IngredientCatalogue.swedish,
          ),
      ],
      source: (l) => ItemSource(
        type: 'manual',
        id: 'voice:${const Uuid().v4()}',
        quantity: l.quantity,
        unit: l.unit,
      ),
    );
  }

  Future<String> _listId(FamilyStore store) async {
    if (await ref.read(currentListProvider.future) case final id?) return id;
    final name = mounted ? context.l10n.shoppingDefaultList : 'Shopping';
    final id = await store.saveShoppingList(
      ShoppingListPayload.write(name: name),
    );
    await ref.read(currentListProvider.notifier).choose(id);
    return id;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
