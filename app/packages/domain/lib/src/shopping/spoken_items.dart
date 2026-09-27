/// What someone said to the shopping list ("mjölk, ägg och bröd"), as the
/// items they meant: split at commas and the words that join a list, in
/// Swedish and English, with a lead-in ("lägg till", "add") and a trailing
/// "to the list" left out. Amounts stay with their item, for the
/// ingredient parser to read.
List<String> spokenItems(String said) {
  var text = said.trim();
  text = text.replaceFirst(
    RegExp(
      r'^(lägg till|lägg in|skriv upp|köp|add|buy|put)\s+',
      caseSensitive: false,
    ),
    '',
  );
  text = text.replaceFirst(
    RegExp(
      r'\s+(på|till|i|to|on)\s+(listan|inköpslistan|handlingslistan|'
      r'the list|the shopping list|my list|my shopping list)\s*$',
      caseSensitive: false,
    ),
    '',
  );
  return [
    for (final part in text.split(
      RegExp(r'\s*,\s*|\s+(?:och|and|samt|plus|också)\s+',
          caseSensitive: false),
    ))
      if (_clean(part) case final item when item.isNotEmpty) item,
  ];
}

String _clean(String part) => part
    .trim()
    .replaceFirst(
        RegExp(r'^(och|and|samt|plus)\b\s*', caseSensitive: false), '')
    .replaceAll(RegExp(r'[.!?]+$'), '')
    .trim();
