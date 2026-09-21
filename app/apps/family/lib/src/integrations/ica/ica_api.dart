import 'dart:convert';
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'ica_auth.dart';

/// ICA's shopping lists, as far as this app needs them.
///
/// Read the lists, read one list's rows, add rows, strike rows through.
/// No deleting and no clearing: the rule this integration keeps is that a
/// row it did not create is not its business (see `planShopPush`).
///
/// Every call is made by the phone. The gateway refuses addresses outside
/// Sweden, so it could not run on the family's server even if that were
/// wanted — and it is not, because the server cannot read the family's
/// list either.
class IcaApi {
  IcaApi(this._auth, {http.Client? client})
    : _http = client ?? http.Client();

  final IcaAuth _auth;
  final http.Client _http;

  static const _base = 'https://apimgw-pub.ica.se';
  static const _lists =
      'sverige/digx/mobile/shoppinglistservice/v1/shoppinglists';

  /// The account's lists, newest first as ICA orders them — their primary
  /// list ("Handla") comes back first.
  Future<List<IcaList>> lists() async {
    final body = await _get(_lists);
    if (body == null) return const [];
    return [
      for (final raw in (body['shoppingLists'] as List<dynamic>? ?? const []))
        IcaList.fromJson(raw as Map<String, dynamic>),
    ];
  }

  /// One list, with its rows.
  Future<IcaList?> list(String offlineId) async {
    final body = await _get('$_lists/$offlineId');
    return body == null ? null : IcaList.fromJson(body);
  }

  /// Adds rows and strikes rows through, in one call.
  ///
  /// Returns the offline ids of the rows created, so the caller can
  /// remember which rows on that list are its own — the only way to keep
  /// the promise never to touch anyone else's.
  Future<List<String>?> push({
    required String listId,
    required List<ListedItem> add,
    required List<String> strike,
    required List<IcaRow> existing,
  }) async {
    final random = Random();
    final created = [
      for (final item in add)
        {
          'offlineId': _offlineId(),
          'productName': item.name,
          // Negative source ids mean free text rather than a product from
          // ICA's catalogue, which is what a family's list holds.
          'sourceId': -(1000000 + random.nextInt(1000000000 - 1000000)),
          'isStrikedOver': false,
          'recipes': <Object>[],
          if (item.quantity != null) 'quantity': item.quantity,
          if (item.unit != null && item.unit!.isNotEmpty) 'unit': item.unit,
        },
    ];

    final byId = {for (final row in existing) row.id: row};
    final changed = [
      for (final id in strike)
        if (byId[id] != null)
          {
            ...byId[id]!.raw,
            'isStrikedOver': true,
            'latestChange': DateTime.now().toUtc().toIso8601String(),
          },
    ];

    if (created.isEmpty && changed.isEmpty) return const [];

    final ok = await _post('$_lists/$listId/sync', {
      if (created.isNotEmpty) 'createdRows': created,
      if (changed.isNotEmpty) 'changedRows': changed,
    });
    if (!ok) return null;
    return [for (final row in created) row['offlineId'] as String];
  }

  static String _offlineId() {
    // ICA's own app uses upper-case UUIDs for these.
    final random = Random();
    String hex(int n) => [
      for (var i = 0; i < n; i++) random.nextInt(16).toRadixString(16),
    ].join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
            'a${hex(3)}-${hex(12)}'
        .toUpperCase();
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    final token = await _auth.accessToken();
    if (token == null) return null;
    try {
      final response = await _http.get(
        Uri.parse('$_base/$path'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 451) {
        // Their rule: the gateway is for Sweden. Nothing to fix here.
        debugPrint('ICA is not reachable from this country');
        return null;
      }
      if (response.statusCode >= 300) {
        debugPrint('ICA answered ${response.statusCode} to $path');
        return null;
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on Object catch (e) {
      debugPrint('ICA request failed: $e');
      return null;
    }
  }

  Future<bool> _post(String path, Map<String, Object?> body) async {
    final token = await _auth.accessToken();
    if (token == null) return false;
    try {
      final response = await _http.post(
        Uri.parse('$_base/$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode >= 300) {
        debugPrint('ICA answered ${response.statusCode} to $path');
        return false;
      }
      return true;
    } on Object catch (e) {
      debugPrint('ICA request failed: $e');
      return false;
    }
  }
}

class IcaList {
  const IcaList({required this.id, required this.title, required this.rows});

  final String id;
  final String title;
  final List<IcaRow> rows;

  static IcaList fromJson(Map<String, dynamic> json) => IcaList(
    id: json['offlineId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    rows: [
      for (final raw in (json['rows'] as List<dynamic>? ?? const []))
        IcaRow.fromJson(raw as Map<String, dynamic>),
    ],
  );
}

class IcaRow {
  const IcaRow({
    required this.id,
    required this.name,
    required this.struckThrough,
    required this.raw,
  });

  final String id;
  final String name;
  final bool struckThrough;

  /// What ICA sent, kept whole so a change sends their fields back
  /// unaltered rather than a version of the row we invented.
  final Map<String, dynamic> raw;

  static IcaRow fromJson(Map<String, dynamic> json) => IcaRow(
    id: json['offlineId'] as String? ?? '',
    name: json['productName'] as String? ?? '',
    struckThrough: json['isStrikedOver'] as bool? ?? false,
    raw: json,
  );
}

final icaApiProvider = Provider<IcaApi>(
  (ref) => IcaApi(ref.watch(icaAuthProvider)),
);
