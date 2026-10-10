/// What a thing on the family's things list is: shoes, clothes, what
/// school or football asks for. Not the shop's aisles, which are for food.
enum ThingCategory { clothes, shoes, school, sport, home, gift, other }

/// Words, lower case, that make a thing what it is. A word counts when a
/// word of the name ends with it ("vinterkängor") or, for the [_inside]
/// lists, holds it anywhere ("fotbollsskor"). Earlier categories win: a
/// football boot is football before it is a shoe.
const _inside = <ThingCategory, List<String>>{
  ThingCategory.gift: ['present', 'kalas', 'inslag', 'gift', 'birthday'],
  ThingCategory.sport: [
    'fotboll', 'football', 'soccer', 'innebandy', 'handboll', 'hockey',
    'bandy', 'tennis', 'golf', 'ridning', 'ridhjälm', 'benskydd',
    'match', 'träning', 'simglas', 'baddräkt', 'badbyxor', 'badmössa',
    'skridsko', 'slalom', 'längdskid', 'målvakt', 'shin guard', 'goggles',
  ],
  ThingCategory.school: [
    'skolväska', 'ryggsäck', 'pennfodral', 'miniräknare', 'gympapåse',
    'hörlurar', 'linjal', 'sudd', 'skrivbok', 'kollegieblock', 'pärm',
    'backpack', 'pencil', 'eraser', 'ruler', 'calculator', 'notebook',
    'headphones',
  ],
};

const _endings = <ThingCategory, List<String>>{
  ThingCategory.school: ['penna', 'pennor', 'block'],
  ThingCategory.shoes: _shoeWords,
  ThingCategory.clothes: _clothesWords,
  ThingCategory.home: [
    'lampa', 'lampor', 'batteri', 'batterier', 'lakan', 'kudde', 'täcke',
    'handduk', 'handdukar', 'gardin', 'gardiner', 'förvaring', 'låda',
    'lådor', 'bulbs', 'batteries', 'towels', 'sheets',
  ],
};

const _shoeWords = [
  'sko', 'skor', 'känga', 'kängor', 'stövel', 'stövlar', 'toffel',
  'tofflor', 'sandal', 'sandaler', 'sneakers', 'shoes', 'boots',
  'trainers', 'slippers', 'wellies',
];

const _clothesWords = [
  'overall', 'byxor', 'jacka', 'jackor', 'tröja', 'tröjor', 'strumpor',
  'mössa', 'mössor', 'vantar', 'handskar', 'kalsonger', 'trosor', 'linne',
  'klänning', 'kjol', 'shorts', 'pyjamas', 'underställ', 'halsduk', 'keps',
  'skjorta', 't-shirt', 'tisha', 'jeans', 'body', 'kläder', 'jacket',
  'coat', 'trousers', 'socks', 'hat', 'gloves', 'mittens', 'shirt',
  'dress', 'jumper', 'sweater', 'clothes',
];

/// Which category wins when a name fits several.
const _precedence = [
  ThingCategory.gift,
  ThingCategory.sport,
  ThingCategory.school,
  ThingCategory.shoes,
  ThingCategory.clothes,
  ThingCategory.home,
];

List<String> _words(String name) => name
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}-]+', unicode: true))
    .where((w) => w.isNotEmpty)
    .toList();

bool _endsWithAny(List<String> words, List<String> endings) =>
    words.any((w) => endings.any(w.endsWith));

/// What [name] most likely is, for the list to put it in the right group.
/// A guess: the person can always choose another.
ThingCategory guessThingCategory(String name) {
  final lower = name.toLowerCase();
  final words = _words(name);
  for (final category in _precedence) {
    if (_inside[category] case final inside?
        when inside.any(lower.contains)) {
      return category;
    }
    if (_endings[category] case final endings?
        when _endsWithAny(words, endings)) {
      return category;
    }
  }
  return ThingCategory.other;
}

enum SizeKind { shoe, clothes, custom }

/// One line of a child's size card: "Skor 35, measured 12 Aug".
class SizeEntry {
  const SizeEntry({
    required this.kind,
    required this.value,
    this.label,
    this.measuredAt,
  });

  final SizeKind kind;

  /// What it is a size of, for [SizeKind.custom] ("Hjälm").
  final String? label;

  /// As written: "35", "140", "52–56", "S".
  final String value;

  /// When someone last checked it.
  final DateTime? measuredAt;

  /// Children grow: a size checked more than six months ago is worth
  /// asking about again before anyone buys to it.
  bool isStale(DateTime now) =>
      measuredAt != null && now.difference(measuredAt!).inDays > 183;
}

/// The size [name] is bought in, from a child's [card]: a row of the
/// card's own whose label is in the name first ("cykelhjälm" takes
/// "Hjälm"), then the shoe size for anything worn on the feet, then the
/// clothes size for anything else worn.
SizeEntry? sizeFor(String name, List<SizeEntry> card) {
  final lower = name.toLowerCase();
  for (final e in card) {
    if (e.kind != SizeKind.custom) continue;
    final label = e.label?.trim().toLowerCase() ?? '';
    if (label.isNotEmpty && lower.contains(label)) return e;
  }
  final words = _words(name);
  final kind = _endsWithAny(words, _shoeWords)
      ? SizeKind.shoe
      : _endsWithAny(words, _clothesWords)
      ? SizeKind.clothes
      : switch (guessThingCategory(name)) {
          ThingCategory.shoes => SizeKind.shoe,
          ThingCategory.clothes => SizeKind.clothes,
          _ => null,
        };
  return card.where((e) => e.kind == kind).firstOrNull;
}

/// "Fotbollsskor till Oliver" as the thing and who it is for: a trailing
/// "till", "åt", "för" or "for" and a member's name (their first name is
/// enough). [members] are (id, display name). A name that is nobody in
/// the family stays part of the thing: "kalaspresent till Ella".
(String, String?) forWhom(String text, List<(String, String)> members) {
  final match = RegExp(
    r'^(.*\S)\s+(?:till|åt|för|for)\s+([^\s.!?]+(?:\s+[^\s.!?]+)?)\s*[.!?]*$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (match == null) return (text.trim(), null);
  final thing = match.group(1)!;
  final said = match.group(2)!.toLowerCase();
  for (final (id, name) in members) {
    final full = name.trim().toLowerCase();
    final first = full.split(RegExp(r'\s+')).first;
    if (said == full || said == first) return (thing, id);
  }
  return (text.trim(), null);
}

/// [forWhom] over a spoken list: "fotbollsskor och benskydd till Oliver"
/// means both are Oliver's, so when only one member is named, everything
/// unnamed is theirs too.
List<(String, String?)> forWhomAll(
  List<String> items,
  List<(String, String)> members,
) {
  final read = [for (final i in items) forWhom(i, members)];
  final named = {
    for (final (_, id) in read)
      if (id != null) id,
  };
  if (named.length != 1) return read;
  return [for (final (thing, id) in read) (thing, id ?? named.single)];
}
