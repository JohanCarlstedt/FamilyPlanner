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

/// What was said to Siri while the app was closed: items for the
/// shopping list and activities to log. Siri's intents run without the
/// app, so they write it down (ios/Runner/AppDelegate.swift, VoiceQueue)
/// and this does it when the app starts or comes back.
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
    _lifecycle = AppLifecycleListener(onResume: _take);
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    if (kIsWeb || !Platform.isIOS || _taking) return;
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
      if (shopping.isEmpty && activities.isEmpty) return;
      final store = await ref.read(familyStoreProvider.future);
      if (shopping.isNotEmpty) {
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
    }
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
