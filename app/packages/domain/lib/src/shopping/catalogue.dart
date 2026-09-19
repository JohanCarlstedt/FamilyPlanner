/// Aisles, for walking the shop in order (spec §4 `ingredient.category`).
enum Aisle { produce, bakery, dairy, meat, frozen, pantry, household, other }

/// A canonical ingredient: what "2 gul lök" and "1 onion" both are.
class Ingredient {
  const Ingredient(this.key, this.name, this.category, this.synonyms);

  /// Stable across versions; lists store it.
  final String key;

  /// What the list shows.
  final String name;
  final Aisle category;

  /// Lower-case words recipes use for it, singular and plural.
  final List<String> synonyms;
}

/// The global seed catalogue (spec §4 "two-tier catalogue"), in Swedish.
/// Matching is by the longest synonym at a word boundary, so "neutral
/// rapsolja" is rapeseed oil and "hackad persilja" parsley.
class IngredientCatalogue {
  const IngredientCatalogue(this.ingredients);

  final List<Ingredient> ingredients;

  Ingredient? byKey(String key) {
    for (final i in ingredients) {
      if (i.key == key) return i;
    }
    return null;
  }

  Ingredient? match(String name) {
    final text = ' ${name.toLowerCase().trim()} ';
    Ingredient? best;
    var bestLength = 0;
    for (final i in ingredients) {
      for (final s in [i.name, ...i.synonyms]) {
        if (s.length > bestLength && text.contains(' $s ')) {
          best = i;
          bestLength = s.length;
        }
      }
    }
    return best;
  }

  static const swedish = IngredientCatalogue([
    // Frukt & grönt
    Ingredient('onion', 'gul lök', Aisle.produce,
        ['lök', 'lökar', 'gul lök', 'gula lökar', 'onion', 'onions']),
    Ingredient('red_onion', 'rödlök', Aisle.produce,
        ['rödlök', 'rödlökar', 'röd lök', 'röda lökar']),
    Ingredient(
        'leek', 'purjolök', Aisle.produce, ['purjolök', 'purjolökar', 'purjo']),
    Ingredient('garlic', 'vitlök', Aisle.produce,
        ['vitlök', 'vitlöksklyfta', 'vitlöksklyftor', 'garlic']),
    Ingredient('potato', 'potatis', Aisle.produce, [
      'potatis',
      'potatisar',
      'färskpotatis',
      'fast potatis',
      'mjölig potatis'
    ]),
    Ingredient('sweet_potato', 'sötpotatis', Aisle.produce, ['sötpotatis']),
    Ingredient('carrot', 'morötter', Aisle.produce, ['morot', 'morötter']),
    Ingredient('tomato', 'tomater', Aisle.produce,
        ['tomat', 'tomater', 'körsbärstomater', 'cocktailtomater']),
    Ingredient(
        'cucumber', 'gurka', Aisle.produce, ['gurka', 'gurkor', 'slanggurka']),
    Ingredient('bell_pepper', 'paprika', Aisle.produce,
        ['paprika', 'paprikor', 'röd paprika', 'gul paprika']),
    Ingredient('chili', 'chili', Aisle.produce,
        ['chili', 'chilifrukt', 'chilifrukter']),
    Ingredient('lettuce', 'sallad', Aisle.produce,
        ['sallad', 'isbergssallad', 'romansallad', 'salladshuvud']),
    Ingredient('spinach', 'spenat', Aisle.produce,
        ['spenat', 'babyspenat', 'bladspenat']),
    Ingredient('broccoli', 'broccoli', Aisle.produce, ['broccoli']),
    Ingredient('cauliflower', 'blomkål', Aisle.produce, ['blomkål']),
    Ingredient('cabbage', 'vitkål', Aisle.produce, ['vitkål', 'kål']),
    Ingredient('zucchini', 'zucchini', Aisle.produce, ['zucchini', 'squash']),
    Ingredient(
        'aubergine', 'aubergine', Aisle.produce, ['aubergine', 'auberginer']),
    Ingredient('mushroom', 'champinjoner', Aisle.produce,
        ['champinjon', 'champinjoner', 'svamp']),
    Ingredient('avocado', 'avokado', Aisle.produce, ['avokado', 'avokador']),
    Ingredient('lemon', 'citron', Aisle.produce, [
      'citron',
      'citroner',
      'citronjuice',
      'citronsaft',
      'färskpressad citronjuice'
    ]),
    Ingredient(
        'lime', 'lime', Aisle.produce, ['lime', 'limefrukt', 'limejuice']),
    Ingredient('apple', 'äpplen', Aisle.produce, ['äpple', 'äpplen']),
    Ingredient('banana', 'bananer', Aisle.produce, ['banan', 'bananer']),
    Ingredient(
        'parsley', 'persilja', Aisle.produce, ['persilja', 'bladpersilja']),
    Ingredient('dill', 'dill', Aisle.produce, ['dill']),
    Ingredient('basil', 'basilika', Aisle.produce, ['basilika']),
    Ingredient('coriander', 'koriander', Aisle.produce,
        ['koriander', 'färsk koriander']),
    Ingredient('chives', 'gräslök', Aisle.produce, ['gräslök']),
    Ingredient(
        'ginger', 'ingefära', Aisle.produce, ['ingefära', 'färsk ingefära']),
    Ingredient(
        'corn', 'majs', Aisle.produce, ['majs', 'majskolv', 'majskolvar']),
    // Bröd
    Ingredient('bread', 'bröd', Aisle.bakery,
        ['bröd', 'formbröd', 'rostbröd', 'limpa']),
    Ingredient('tortilla', 'tortillabröd', Aisle.bakery,
        ['tortilla', 'tortillas', 'tortillabröd']),
    Ingredient(
        'hamburger_buns', 'hamburgerbröd', Aisle.bakery, ['hamburgerbröd']),
    Ingredient('hard_bread', 'knäckebröd', Aisle.bakery, ['knäckebröd']),
    // Mejeri
    Ingredient('milk', 'mjölk', Aisle.dairy,
        ['mjölk', 'mellanmjölk', 'standardmjölk', 'lättmjölk', 'milk']),
    Ingredient('cream', 'grädde', Aisle.dairy,
        ['grädde', 'vispgrädde', 'matlagningsgrädde', 'cream']),
    Ingredient('creme_fraiche', 'crème fraiche', Aisle.dairy,
        ['crème fraiche', 'creme fraiche', 'crème fraîche']),
    Ingredient('sour_cream', 'gräddfil', Aisle.dairy, ['gräddfil']),
    Ingredient('yoghurt', 'yoghurt', Aisle.dairy,
        ['yoghurt', 'turkisk yoghurt', 'grekisk yoghurt', 'naturell yoghurt']),
    Ingredient('filmjolk', 'filmjölk', Aisle.dairy, ['filmjölk', 'fil']),
    Ingredient('butter', 'smör', Aisle.dairy,
        ['smör', 'bregott', 'smör eller margarin', 'margarin']),
    Ingredient('cheese', 'ost', Aisle.dairy,
        ['ost', 'riven ost', 'hårdost', 'prästost', 'herrgårdsost', 'grevé']),
    Ingredient('parmesan', 'parmesan', Aisle.dairy,
        ['parmesan', 'parmesanost', 'riven parmesan']),
    Ingredient('mozzarella', 'mozzarella', Aisle.dairy, ['mozzarella']),
    Ingredient('feta', 'fetaost', Aisle.dairy, ['feta', 'fetaost']),
    Ingredient(
        'cream_cheese', 'färskost', Aisle.dairy, ['färskost', 'philadelphia']),
    Ingredient(
        'cottage_cheese', 'keso', Aisle.dairy, ['keso', 'cottage cheese']),
    Ingredient('egg', 'ägg', Aisle.dairy,
        ['ägg', 'äggula', 'äggulor', 'äggvita', 'äggvitor', 'eggs']),
    Ingredient(
        'oat_milk', 'havredryck', Aisle.dairy, ['havredryck', 'havremjölk']),
    // Kött & fisk
    Ingredient('minced_beef', 'nötfärs', Aisle.meat,
        ['nötfärs', 'köttfärs', 'blandfärs']),
    Ingredient('minced_pork', 'fläskfärs', Aisle.meat, ['fläskfärs']),
    Ingredient('chicken_fillet', 'kycklingfilé', Aisle.meat,
        ['kycklingfilé', 'kycklingfiléer', 'kycklingbröst', 'kyckling']),
    Ingredient('chicken_thigh', 'kycklinglårfilé', Aisle.meat,
        ['kycklinglårfilé', 'kycklinglår']),
    Ingredient('bacon', 'bacon', Aisle.meat, ['bacon']),
    Ingredient(
        'ham', 'skinka', Aisle.meat, ['skinka', 'kokt skinka', 'rökt skinka']),
    Ingredient('sausage', 'korv', Aisle.meat,
        ['korv', 'falukorv', 'prinskorv', 'grillkorv', 'chorizo']),
    Ingredient('pork_fillet', 'fläskfilé', Aisle.meat, ['fläskfilé']),
    Ingredient('beef', 'nötkött', Aisle.meat,
        ['nötkött', 'högrev', 'entrecote', 'oxfilé']),
    Ingredient('salmon', 'lax', Aisle.meat, [
      'lax',
      'laxfilé',
      'laxfiléer',
      'kallrökt lax',
      'gravad lax',
      'varmrökt lax'
    ]),
    Ingredient(
        'cod', 'torsk', Aisle.meat, ['torsk', 'torskfilé', 'torskfiléer']),
    Ingredient('white_fish', 'vit fisk', Aisle.meat,
        ['sej', 'sejfilé', 'kolja', 'vit fisk', 'fiskfilé']),
    Ingredient('shrimp', 'räkor', Aisle.meat, ['räkor', 'skalade räkor']),
    Ingredient('tofu', 'tofu', Aisle.meat, ['tofu']),
    // Fryst
    Ingredient('frozen_peas', 'gröna ärtor', Aisle.frozen,
        ['ärtor', 'gröna ärtor', 'frysta ärtor']),
    Ingredient('frozen_berries', 'frysta bär', Aisle.frozen,
        ['frysta bär', 'blåbär', 'hallon', 'jordgubbar']),
    Ingredient('fish_fingers', 'fiskpinnar', Aisle.frozen, ['fiskpinnar']),
    Ingredient('ice_cream', 'glass', Aisle.frozen, ['glass', 'vaniljglass']),
    // Skafferi
    Ingredient('flour', 'vetemjöl', Aisle.pantry, ['vetemjöl', 'mjöl']),
    Ingredient('sugar', 'socker', Aisle.pantry, ['socker', 'strösocker']),
    Ingredient('icing_sugar', 'florsocker', Aisle.pantry, ['florsocker']),
    Ingredient('brown_sugar', 'farinsocker', Aisle.pantry,
        ['farinsocker', 'muscovadosocker']),
    Ingredient('salt', 'salt', Aisle.pantry, ['salt', 'flingsalt', 'havssalt']),
    Ingredient('pepper', 'svartpeppar', Aisle.pantry,
        ['peppar', 'svartpeppar', 'nymalen svartpeppar', 'vitpeppar']),
    Ingredient('rapeseed_oil', 'rapsolja', Aisle.pantry,
        ['rapsolja', 'neutral olja', 'matolja']),
    Ingredient('olive_oil', 'olivolja', Aisle.pantry, ['olivolja']),
    Ingredient('vinegar', 'vinäger', Aisle.pantry, [
      'vinäger',
      'vitvinsvinäger',
      'rödvinsvinäger',
      'ättika',
      'balsamvinäger'
    ]),
    Ingredient('mustard', 'senap', Aisle.pantry,
        ['senap', 'dijonsenap', 'grovkornig senap']),
    Ingredient('ketchup', 'ketchup', Aisle.pantry, ['ketchup']),
    Ingredient('mayonnaise', 'majonnäs', Aisle.pantry, ['majonnäs']),
    Ingredient('soy_sauce', 'soja', Aisle.pantry,
        ['soja', 'sojasås', 'japansk soja', 'kinesisk soja']),
    Ingredient('stock', 'buljong', Aisle.pantry, [
      'buljong',
      'buljongtärning',
      'buljongtärningar',
      'hönsbuljong',
      'grönsaksbuljong',
      'kalvfond',
      'fond'
    ]),
    Ingredient('crushed_tomatoes', 'krossade tomater', Aisle.pantry,
        ['krossade tomater', 'tomatkross', 'passerade tomater']),
    Ingredient('tomato_paste', 'tomatpuré', Aisle.pantry, ['tomatpuré']),
    Ingredient('coconut_milk', 'kokosmjölk', Aisle.pantry,
        ['kokosmjölk', 'kokosgrädde']),
    Ingredient('pasta', 'pasta', Aisle.pantry, [
      'pasta',
      'spagetti',
      'spaghetti',
      'penne',
      'makaroner',
      'fusilli',
      'tagliatelle',
      'lasagneplattor'
    ]),
    Ingredient('rice', 'ris', Aisle.pantry,
        ['ris', 'jasminris', 'basmatiris', 'långkornigt ris', 'risottoris']),
    Ingredient('noodles', 'nudlar', Aisle.pantry,
        ['nudlar', 'äggnudlar', 'risnudlar']),
    Ingredient(
        'bulgur', 'bulgur', Aisle.pantry, ['bulgur', 'couscous', 'matvete']),
    Ingredient('oats', 'havregryn', Aisle.pantry, ['havregryn']),
    Ingredient('lentils', 'linser', Aisle.pantry, ['linser', 'röda linser']),
    Ingredient('beans', 'bönor', Aisle.pantry,
        ['bönor', 'kidneybönor', 'svarta bönor', 'vita bönor', 'kikärtor']),
    Ingredient('nuts', 'nötter', Aisle.pantry, [
      'nötter',
      'hasselnötter',
      'valnötter',
      'cashewnötter',
      'mandel',
      'jordnötter'
    ]),
    Ingredient('honey', 'honung', Aisle.pantry, ['honung']),
    Ingredient('baking_powder', 'bakpulver', Aisle.pantry, ['bakpulver']),
    Ingredient('yeast', 'jäst', Aisle.pantry, ['jäst', 'torrjäst']),
    Ingredient('vanilla_sugar', 'vaniljsocker', Aisle.pantry, ['vaniljsocker']),
    Ingredient('cocoa', 'kakao', Aisle.pantry, ['kakao', 'kakaopulver']),
    Ingredient('curry', 'curry', Aisle.pantry,
        ['curry', 'currypulver', 'currypasta', 'röd currypasta']),
    Ingredient('paprika_powder', 'paprikapulver', Aisle.pantry,
        ['paprikapulver', 'rökt paprikapulver']),
    Ingredient('cumin', 'spiskummin', Aisle.pantry, ['spiskummin']),
    Ingredient(
        'oregano', 'oregano', Aisle.pantry, ['oregano', 'torkad oregano']),
    Ingredient('thyme', 'timjan', Aisle.pantry, ['timjan', 'torkad timjan']),
    Ingredient('cinnamon', 'kanel', Aisle.pantry, ['kanel', 'malen kanel']),
    Ingredient('taco_spice', 'tacokrydda', Aisle.pantry,
        ['tacokrydda', 'tacokryddmix']),
    Ingredient('taco_sauce', 'tacosås', Aisle.pantry, ['tacosås', 'salsa']),
    Ingredient('coffee', 'kaffe', Aisle.pantry, ['kaffe', 'bryggkaffe']),
    Ingredient('tea', 'te', Aisle.pantry, ['te']),
    Ingredient('juice', 'juice', Aisle.pantry, ['juice', 'apelsinjuice']),
    // Hushåll
    Ingredient('toilet_paper', 'toalettpapper', Aisle.household,
        ['toalettpapper', 'toapapper']),
    Ingredient(
        'kitchen_roll', 'hushållspapper', Aisle.household, ['hushållspapper']),
    Ingredient('dish_soap', 'diskmedel', Aisle.household,
        ['diskmedel', 'maskindiskmedel', 'disktabletter']),
    Ingredient('detergent', 'tvättmedel', Aisle.household, ['tvättmedel']),
  ]);
}
