/// What a unit measures. Only amounts of the same kind add up; each kind of
/// package is its own, since a package is whatever the shop sells.
enum Measure {
  mass,
  volume,
  count,
  clove,
  pinch,
  package,
  can,
  bunch,
  pot,
  bag,
  slice
}

/// Units as Swedish recipes use them (spec §4 "Swedish units are the real
/// work"): `factor` converts to the measure's base (g, ml, pieces).
enum Unit {
  g(Measure.mass, 1, 'g'),
  kg(Measure.mass, 1000, 'kg'),
  ml(Measure.volume, 1, 'ml'),
  cl(Measure.volume, 10, 'cl'),
  dl(Measure.volume, 100, 'dl'),
  l(Measure.volume, 1000, 'l'),
  msk(Measure.volume, 15, 'msk'),
  tsk(Measure.volume, 5, 'tsk'),
  krm(Measure.volume, 1, 'krm'),
  st(Measure.count, 1, 'st'),
  klyfta(Measure.clove, 1, 'klyftor'),
  nypa(Measure.pinch, 1, 'nypa'),
  forp(Measure.package, 1, 'förp'),
  pkt(Measure.package, 1, 'pkt'),
  burk(Measure.can, 1, 'burk'),
  knippe(Measure.bunch, 1, 'knippe'),
  kruka(Measure.pot, 1, 'kruka'),
  pase(Measure.bag, 1, 'påse'),
  skiva(Measure.slice, 1, 'skivor');

  const Unit(this.measure, this.factor, this.label);

  final Measure measure;
  final double factor;
  final String label;

  /// Packages of different kinds never add up, even though they're all
  /// "one of something".
  Object get mergeKey => measure == Measure.package ? this : measure;

  static const _words = {
    'g': g,
    'gr': g,
    'gram': g,
    'kg': kg,
    'kilo': kg,
    'ml': ml,
    'cl': cl,
    'dl': dl,
    'l': l,
    'liter': l,
    'msk': msk,
    'matsked': msk,
    'matskedar': msk,
    'tsk': tsk,
    'tesked': tsk,
    'teskedar': tsk,
    'krm': krm,
    'kryddmått': krm,
    'st': st,
    'stycken': st,
    'styck': st,
    'stk': st,
    'klyfta': klyfta,
    'klyftor': klyfta,
    'nypa': nypa,
    'nypor': nypa,
    'förp': forp,
    'förpackning': forp,
    'förpackningar': forp,
    'pkt': pkt,
    'paket': pkt,
    'burk': burk,
    'burkar': burk,
    'knippe': knippe,
    'knippen': knippe,
    'kruka': kruka,
    'krukor': kruka,
    'påse': pase,
    'påsar': pase,
    'skiva': skiva,
    'skivor': skiva,
  };

  /// The unit a recipe word means, or null.
  static Unit? parse(String word) =>
      _words[word.toLowerCase().replaceAll(RegExp(r'\.$'), '')];
}

/// "2,5", "3": Swedish decimals, no trailing zero.
String formatAmount(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}
