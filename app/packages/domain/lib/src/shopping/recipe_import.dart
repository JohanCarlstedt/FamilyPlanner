import 'dart:convert';

/// A recipe as a site publishes it for search engines: schema.org `Recipe`
/// in JSON-LD (spec §4 "Importing from Swedish recipe sites", tier 1). ICA,
/// Köket, Arla and most others do. The method stays with the site; only
/// what's needed to plan and shop is taken.
class RecipeImport {
  const RecipeImport({
    required this.title,
    required this.ingredients,
    this.servings,
    this.totalMinutes,
    this.imageUrl,
    this.categories = const [],
  });

  final String title;

  /// Ingredient lines as the site wrote them; parsed later, in review.
  final List<String> ingredients;
  final int? servings;
  final int? totalMinutes;
  final String? imageUrl;
  final List<String> categories;

  static final _script = RegExp(
    // Arla writes the plus as an HTML entity.
    r'''<script[^>]*type=["']?application/ld(?:\+|&#x2B;|&#43;)json["']?[^>]*>(.*?)</script>''',
    dotAll: true,
    caseSensitive: false,
  );

  /// The first recipe on [html], or null if it publishes none.
  static RecipeImport? fromHtml(String html) {
    for (final m in _script.allMatches(html)) {
      final Object? data;
      try {
        data = jsonDecode(m.group(1)!.trim());
      } on FormatException {
        continue;
      }
      if (_find(data) case final r?) return _read(r);
    }
    return null;
  }

  static Map<String, dynamic>? _find(Object? node) {
    switch (node) {
      case final Map<String, dynamic> map:
        final type = map['@type'];
        if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
          return map;
        }
        return _find(map['@graph']);
      case final List<dynamic> list:
        for (final item in list) {
          if (_find(item) case final r?) return r;
        }
    }
    return null;
  }

  static RecipeImport? _read(Map<String, dynamic> r) {
    final title = _text(r['name']);
    if (title == null) return null;
    final prep = _minutes(r['prepTime']);
    final cook = _minutes(r['cookTime']);
    return RecipeImport(
      title: title,
      ingredients: [
        for (final i in _list(r['recipeIngredient'] ?? r['ingredients']))
          if (_text(i) case final t? when t.isNotEmpty) t,
      ],
      servings: _servings(r['recipeYield']),
      totalMinutes: _minutes(r['totalTime']) ??
          (prep == null && cook == null ? null : (prep ?? 0) + (cook ?? 0)),
      imageUrl: _image(r['image']),
      categories: [
        for (final c in _list(r['recipeCategory']))
          for (final part in (_text(c) ?? '').split(','))
            if (part.trim().isNotEmpty) part.trim(),
      ],
    );
  }

  static List<dynamic> _list(Object? v) => switch (v) {
        null => const [],
        final List<dynamic> l => l,
        _ => [v],
      };

  static String? _text(Object? v) => switch (v) {
        final String s => _unescape(s.trim()),
        final num n => '$n',
        _ => null,
      };

  static int? _servings(Object? v) {
    for (final item in _list(v)) {
      if (item is num) return item.round();
      if (item is String) {
        if (RegExp(r'\d+').firstMatch(item) case final m?) {
          return int.parse(m.group(0)!);
        }
      }
    }
    return null;
  }

  /// ISO 8601 durations: PT45M, PT1H5M, P0DT1H.
  static int? _minutes(Object? v) {
    if (v is! String) return null;
    final m = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:\d+S)?)?$',
    ).firstMatch(v.trim());
    if (m == null) return null;
    int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    final total = part(1) * 1440 + part(2) * 60 + part(3);
    return total == 0 ? null : total;
  }

  static String? _image(Object? v) {
    for (final item in _list(v)) {
      if (item is String) return item;
      if (item is Map && item['url'] is String) return item['url'] as String;
    }
    return null;
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
