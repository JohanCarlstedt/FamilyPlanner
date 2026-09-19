import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/store_providers.dart';

final shoppingListsProvider =
    StreamProvider<List<(String, ShoppingListPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchShoppingLists().map(
        (lists) => [
          for (final l in lists)
            if (l.$2.state != ShoppingListState.template) l,
        ],
      );
    });

final shoppingItemsProvider =
    StreamProvider<List<(String, ShoppingItemPayload)>>((ref) async* {
      final store = await ref.watch(familyStoreProvider.future);
      yield* store.watchShoppingItems();
    });

final recipesProvider = StreamProvider<List<(String, RecipePayload)>>((
  ref,
) async* {
  final store = await ref.watch(familyStoreProvider.future);
  yield* store.watchRecipes().map(
    (r) => r..sort((a, b) => a.$2.title.compareTo(b.$2.title)),
  );
});

/// The list this device shows, chosen per device (spec §5: two parents
/// needn't look at the same one).
final currentListProvider = AsyncNotifierProvider<CurrentListNotifier, String?>(
  CurrentListNotifier.new,
);

class CurrentListNotifier extends AsyncNotifier<String?> {
  static const _preference = 'shopping.list';

  @override
  Future<String?> build() async {
    final lists = await ref.watch(shoppingListsProvider.future);
    final chosen = await (await ref.read(devicePreferencesProvider.future))
        .read(_preference);
    if (lists.any((l) => l.$1 == chosen)) return chosen;
    return lists.firstOrNull?.$1;
  }

  Future<void> choose(String id) async {
    await (await ref.read(devicePreferencesProvider.future))
        .write(_preference, id);
    state = AsyncData(id);
  }
}

/// Fetches a recipe page on this phone (spec §4 "Fetching: politely, and
/// only when asked"): one page, because someone asked for that recipe. The
/// family's server never learns what they cook.
Future<RecipeImport> fetchRecipe(String url, {http.Client? client}) async {
  final uri = Uri.parse(url.trim());
  if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
    throw const FormatException('not a web link');
  }
  final response = await (client ?? http.Client())
      .get(uri, headers: {'User-Agent': 'FamilyPlanner/1.0 (family recipe)'})
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw http.ClientException('HTTP ${response.statusCode}');
  }
  final recipe = RecipeImport.fromHtml(
    utf8.decode(response.bodyBytes, allowMalformed: true),
  );
  if (recipe == null) throw const FormatException('no recipe on that page');
  return recipe;
}
