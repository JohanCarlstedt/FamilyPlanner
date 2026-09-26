import 'dart:math';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'city_sprites.dart';
import 'city_words.dart';
import 'trade_sheet.dart' show landmarkEmoji;

/// A child's city, drawn: isometric plots, what they built on them, the
/// town's own buildings, and life — cars, clouds, lit windows at night,
/// fireworks over the square in a week the family jar is full.
///
/// Everything is drawn here rather than loaded, so the city needs no
/// images, works offline, and looks the same on every phone. It is drawn
/// from the [City] alone, so two phones draw the same town.
class CityView extends StatefulWidget {
  const CityView({
    super.key,
    required this.city,
    required this.night,
    required this.festival,
    this.selected,
    this.onTapPlot,
    this.sprites,
    this.happening,
    this.population = 0,
    this.trouble,
    this.plan = false,
    this.still = false,
  });

  final City city;

  /// Drawn once and left still: a small picture of the town, say on
  /// Today, where nothing needs to move and nothing should cost battery.
  final bool still;

  /// Every plot as a flat coloured tile with its symbol, no buildings: so
  /// a plot behind a tall building can be seen and tapped.
  final bool plan;

  /// A fire burning, or a thief about: drawn where it is.
  final Trouble? trouble;

  /// What is going on in the city today, drawn: balloons racing, a whale
  /// in the lake, shooting stars, fireworks for a festival.
  final Happening? happening;

  /// How many people live in the town: that many more out walking.
  final int population;

  /// The city's pictures (city_sprites.dart), or null to draw it as it
  /// was drawn before them: in tests, and while they are still loading.
  final CitySprites? sprites;

  /// Evening and night by the family's clock: windows lit, stars out.
  final bool night;

  /// This week's family jar is full: fireworks over the square.
  final bool festival;

  /// The plot the child has tapped, outlined.
  final (int, int)? selected;

  /// Where a tap lands, as a plot on the map. Null for a view nobody may
  /// build in, such as a parent looking at a child's city.
  final void Function(int x, int y)? onTapPlot;

  @override
  State<CityView> createState() => _CityViewState();
}

class _CityViewState extends State<CityView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMilliseconds / 1000;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nothing moves when the phone has been asked to reduce motion: the
    // city is drawn once, still, with everything in it.
    final still =
        widget.still ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final geometry = _Geometry(box.maxWidth);
      return GestureDetector(
        onTapUp: widget.onTapPlot == null
            ? null
            : (d) {
                // A ⬆️ stands above its building, over another plot's
                // ground: a tap on it means that building.
                for (final l in widget.city.lots) {
                  if (!widget.city.canUpgrade(l.x, l.y)) continue;
                  final marker = _CityPainter.readyMarkerAt(
                    geometry.at(l.x, l.y),
                    geometry.tileHeight,
                  );
                  if ((marker - d.localPosition).distance <
                      geometry.tileHeight * 0.9) {
                    widget.onTapPlot!(l.x, l.y);
                    return;
                  }
                }
                final plot = geometry.plotAt(d.localPosition);
                if (plot != null) widget.onTapPlot!(plot.$1, plot.$2);
              },
        child: CustomPaint(
          size: Size(box.maxWidth, geometry.height),
          painter: _CityPainter(
            city: widget.city,
            geometry: geometry,
            night: widget.night,
            festival: widget.festival,
            selected: widget.selected,
            time: _time,
            sprites: widget.sprites,
            month: DateTime.now().month,
            happening: widget.happening,
            population: widget.population,
            trouble: widget.trouble,
            plan: widget.plan,
          ),
        ),
      );
    },
  );
}

/// Where the middle of the town is drawn in a view [width] wide, and
/// how tall the view is: for zooming the town to fill the screen.
({Offset centre, double height}) cityCentre(double width) {
  final g = _Geometry(width);
  return (centre: g.at(City.centre, City.centre), height: g.height);
}

/// Where each plot is on screen, and which plot a point is on.
class _Geometry {
  _Geometry(double width)
    : tileWidth = width / City.size,
      tileHeight = width / City.size / 2,
      originX = width / 2,
      originY = 96;

  final double tileWidth;
  final double tileHeight;
  final double originX;

  /// Room above the first plot for the tallest tower and the sky.
  final double originY;

  double get height => originY + City.size * tileHeight + 24;

  Offset at(num x, num y) => Offset(
    originX + (x - y) * tileWidth / 2,
    originY + (x + y) * tileHeight / 2,
  );

  (int, int)? plotAt(Offset p) {
    final a = (p.dx - originX) / (tileWidth / 2);
    final b = (p.dy - originY) / (tileHeight / 2);
    final x = ((a + b) / 2).round();
    final y = ((b - a) / 2).round();
    if (x < 0 || y < 0 || x >= City.size || y >= City.size) return null;
    return (x, y);
  }
}

class _CityPainter extends CustomPainter {
  _CityPainter({
    required this.city,
    required this.geometry,
    required this.night,
    required this.festival,
    required this.selected,
    required this.time,
    this.sprites,
    this.month = 6,
    this.happening,
    this.population = 0,
    this.trouble,
    this.plan = false,
  }) : super(repaint: time);

  final bool plan;

  final Happening? happening;
  final int population;
  final Trouble? trouble;

  /// What each building is waiting for, worked out once per city rather
  /// than every frame.
  late final Map<(int, int), Set<Service>> _missing = {
    for (final l in city.lots)
      if (!city.underConstruction(l.x, l.y))
        if (city.missingAt(l.x, l.y) case final m when m.isNotEmpty)
          (l.x, l.y): m,
  };

  /// What is ready to grow: a ⬆️ over each, drawn over the town.
  late final Set<(int, int)> _ready = {
    for (final l in city.lots)
      if (city.canUpgrade(l.x, l.y)) (l.x, l.y),
  };

  /// Where the family's projects stand, by plot.
  late final Map<(int, int), FamilyProject> _projects = {
    for (final MapEntry(key: p, value: at) in city.projectPlots.entries) at: p,
  };

  /// The lake plot a whale shows up in: the same one each time.
  late final (int, int)? _whalePlot =
      (city.water.toList()
            ..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2)))
          .firstOrNull;

  final CitySprites? sprites;

  /// Which month it is, for autumn's trees.
  final int month;

  /// Pictures are drawn smoothly scaled. After dark, the evening picture
  /// (moonlit, windows lit) where there is one; otherwise the day's,
  /// dimmed and blue.
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;
  late final Paint _dimmedPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(
      Color(0xFF6A76A8),
      BlendMode.modulate,
    );

  /// The picture called [name], as the time of day has it.
  CitySprite? _pictureOf(String? name) {
    if (name == null || sprites == null) return null;
    if (night) {
      if (sprites!['$name@night'] case final evening?) return evening;
    }
    return sprites![name];
  }

  /// Stands [sprite] on the plot whose centre is [c].
  void _sprite(Canvas canvas, Offset c, CitySprite sprite) {
    final k = geometry.tileWidth / sprite.plotPx;
    final image = sprite.image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        c.dx - sprite.anchor.dx * k,
        c.dy - sprite.anchor.dy * k,
        image.width * k,
        image.height * k,
      ),
      night && !sprite.evening ? _dimmedPaint : _spritePaint,
    );
  }

  final City city;
  final _Geometry geometry;
  final bool night;
  final bool festival;
  final (int, int)? selected;
  final ValueNotifier<double> time;

  double get t => time.value;

  /// This city's dice, for anything that belongs to the town: two
  /// children's cities never share a street's colours or a field's trees.
  double _n(int x, int y, int salt) => cityNoise(city.seed, x, y, salt);

  static double _hash(int x, int y, int s) {
    var h = (x * 374761393 + y * 668265263 + s * 982451653) & 0xffffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff;
    return ((h ^ (h >> 16)) & 0xffffffff) / 0xffffffff;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    if (plan) {
      _plan(canvas);
      _selection(canvas);
      return;
    }

    // Everything that moves on the ground, sorted by how far back it is,
    // so it is drawn in among the buildings rather than over them: a
    // building nearer the viewer hides someone walking behind it.
    final movers = <int, List<void Function()>>{};
    void place(double depth, void Function() draw) =>
        (movers[depth.round()] ??= []).add(draw);
    _traffic(canvas, place);
    _people(canvas, place);
    // Back to front, so nearer buildings stand in front of further ones.
    for (var s = 0; s < City.size * 2; s++) {
      for (var x = 0; x < City.size; x++) {
        final y = s - x;
        if (y < 0 || y >= City.size) continue;
        _plot(canvas, x, y);
      }
      for (final draw in movers[s] ?? const <void Function()>[]) {
        draw();
      }
    }
    _thief(canvas);
    _air(canvas, size);
    if (happening == Happening.balloonRace && !night) _balloonRace(canvas);
    if (happening == Happening.meteorShower && night) _meteors(canvas);
    if (festival || happening == Happening.festival) _fireworks(canvas);
    _readyMarkers(canvas);
    _selection(canvas);
  }

  /// Where the ⬆️ over a building ready to grow is drawn, for tapping too.
  static Offset readyMarkerAt(Offset plotCentre, double tileHeight) =>
      plotCentre.translate(0, -tileHeight * 1.9);

  /// A green ⬆️ bobbing over each building ready to grow, over everything
  /// so no building hides it.
  void _readyMarkers(Canvas canvas) {
    if (_ready.isEmpty) return;
    final k = _k;
    for (final (x, y) in _ready) {
      final c = geometry.at(x, y);
      final bob = sin(t * 3 + x * 1.3 + y) * 2 * k;
      final at = readyMarkerAt(c, geometry.tileHeight).translate(0, bob);
      final pulse = 1 + 0.12 * sin(t * 5 + x + y);
      canvas
        ..drawCircle(
          at,
          9 * k * pulse,
          Paint()..color = const Color(0x5534C759),
        )
        ..drawCircle(at, 7 * k, Paint()..color = const Color(0xFF2FB344))
        ..drawCircle(
          at,
          7 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 * k
            ..color = Colors.white,
        );
      final arrow = Path()
        ..moveTo(at.dx, at.dy - 4.2 * k)
        ..lineTo(at.dx + 3.6 * k, at.dy)
        ..lineTo(at.dx + 1.4 * k, at.dy)
        ..lineTo(at.dx + 1.4 * k, at.dy + 3.8 * k)
        ..lineTo(at.dx - 1.4 * k, at.dy + 3.8 * k)
        ..lineTo(at.dx - 1.4 * k, at.dy)
        ..lineTo(at.dx - 3.6 * k, at.dy)
        ..close();
      canvas.drawPath(arrow, Paint()..color = Colors.white);
    }
  }

  /// The plot the child tapped, outlined over everything, buildings in
  /// front included, with a marker standing over it: always visible.
  void _selection(Canvas canvas) {
    final at = selected;
    if (at == null) return;
    final c = geometry.at(at.$1, at.$2);
    final ground = _diamond(c);
    final pulse = 0.6 + 0.4 * sin(t * 4);
    canvas
      ..drawPath(
        ground,
        Paint()..color = const Color(0xFFFFE066).withValues(alpha: 0.35),
      )
      ..drawPath(
        ground,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFE066).withValues(alpha: pulse),
      );
    final k = _k;
    final top = c.translate(0, -geometry.tileHeight * 2.2 - sin(t * 4) * 2 * k);
    canvas
      ..drawLine(
        top,
        c.translate(0, -2),
        Paint()
          ..color = const Color(0xCCFFE066)
          ..strokeWidth = 1.2 * k,
      )
      ..drawCircle(top, 4 * k, Paint()..color = const Color(0xFFFFC53D))
      ..drawCircle(top, 1.6 * k, Paint()..color = Colors.white);
  }

  final Map<String, TextPainter> _symbols = {};

  TextPainter _symbol(String text, double size) => _symbols.putIfAbsent(
        '$text@$size',
        () => TextPainter(
          text: TextSpan(text: text, style: TextStyle(fontSize: size)),
          textDirection: TextDirection.ltr,
        )..layout(),
      );

  /// The town from above as a map of plots: each coloured by what stands
  /// there, with its symbol. Nothing is tall, so nothing is hidden.
  void _plan(Canvas canvas) {
    for (var y = 0; y < City.size; y++) {
      for (var x = 0; x < City.size; x++) {
        final c = geometry.at(x, y);
        final ground = _diamond(c);
        final open = city.isOpen(x, y);
        final lot = city.lotAt(x, y);
        final civic = City.civicPlots.entries
            .where((e) => e.value == (x, y) && city.civic.contains(e.key))
            .firstOrNull
            ?.key;
        final project = _projects[(x, y)];
        final (Color fill, String? symbol) = !open
            ? (const Color(0x33447744), null)
            : city.isWater(x, y)
            ? (const Color(0xFF4FA8D8), null)
            : city.isRoad(x, y)
            ? (const Color(0xFF9A9DA3), null)
            : city.underConstruction(x, y)
            ? (const Color(0xFFFFC53D), '🏗️')
            : project != null
            ? (const Color(0xFFE0C3FC), '⭐')
            : civic != null
            ? (const Color(0xFFD0D4DA), civicEmoji(civic))
            : switch (lot?.zone) {
                null => (const Color(0xFFBFE3A8), null),
                Zone.home => (const Color(0xFFFFB38A), '🏠'),
                Zone.shop => (const Color(0xFFFFE08A), '🏪'),
                Zone.park => (const Color(0xFF7BC67B), '🌳'),
                Zone.road => (const Color(0xFF9A9DA3), null),
                Zone.market => (const Color(0xFFE8C07D), '🏛️'),
                Zone.landmark => (
                  const Color(0xFFF4A6C9),
                  lot?.landmark == null ? '⭐' : landmarkEmoji(lot!.landmark!),
                ),
                Zone.sport => (
                  const Color(0xFF9BE39B),
                  lot?.sport == null ? '⚽' : sportEmoji(lot!.sport!),
                ),
                Zone.service => (
                  const Color(0xFFA5C8F0),
                  lot?.service == null ? '⚙️' : serviceEmoji(lot!.service!),
                ),
              };
        canvas
          ..drawPath(ground, Paint()..color = fill)
          ..drawPath(
            ground,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6
              ..color = Colors.white.withValues(alpha: open ? 0.7 : 0.2),
          );
        if (_ready.contains((x, y))) {
          canvas.drawPath(
            ground,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFF2FB344),
          );
        }
        if (symbol != null) {
          final painter = _symbol(symbol, geometry.tileHeight * 0.55);
          painter.paint(
            canvas,
            c - Offset(painter.width / 2, painter.height / 2),
          );
        }
      }
    }
  }

  void _sky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = night ? const Color(0xFF141B33) : const Color(0xFFBFE3F5),
    );
    if (night) {
      final star = Paint()..color = Colors.white;
      for (var i = 0; i < 70; i++) {
        star.color = Colors.white.withValues(alpha: 0.3 + 0.7 * _hash(i, 1, 2));
        canvas.drawRect(
          Rect.fromLTWH(
            _hash(i, 3, 4) * size.width,
            _hash(i, 5, 6) * 120,
            1.6,
            1.6,
          ),
          star,
        );
      }
      return;
    }
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final cx = ((t * 14 * (1 + i * 0.3) + i * 230) % (size.width + 160)) - 80;
      final cy = 26.0 + i * 20;
      canvas
        ..drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 68, height: 20),
          cloud,
        )
        ..drawOval(
          Rect.fromCenter(
            center: Offset(cx + 22, cy - 6),
            width: 44,
            height: 18,
          ),
          cloud,
        );
    }
  }

  Path _diamond(Offset c) {
    final w = geometry.tileWidth / 2, h = geometry.tileHeight / 2;
    return Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - w, c.dy)
      ..close();
  }

  void _plot(Canvas canvas, int x, int y) {
    final c = geometry.at(x, y);
    final ground = _diamond(c);
    final open = city.isOpen(x, y);
    if (city.isWater(x, y)) {
      _water(canvas, c, x, y, open: open);
      if (open && happening == Happening.whale && _whalePlot == (x, y)) {
        _whale(canvas, c);
      }
      return;
    }
    if (!open) {
      canvas.drawPath(
        ground,
        Paint()
          ..color = (night ? const Color(0xFF1E2A3F) : const Color(0xFF9ACB7E))
              .withValues(alpha: 0.35),
      );
      return;
    }
    final road = city.isRoad(x, y);
    final sprite = _pictureOf(citySpriteName(city, x, y, month: month));
    canvas.drawPath(
      ground,
      Paint()
        // Under a picture, grass: a road's picture has its own asphalt and
        // pavement, and a bend's inside corner is verge.
        ..color = road && sprite == null
            ? (night ? const Color(0xFF3A3F4B) : const Color(0xFF8B8E94))
            : (night
                  ? const Color(0xFF2F5A36)
                  : const [
                      Color(0xFF7FC06A),
                      Color(0xFF76B862),
                      Color(0xFF86C46E),
                      Color(0xFF7BBA5E),
                    ][(_n(x, y, 1) * 4).floor() % 4]),
    );
    if (road && sprite != null) _sprite(canvas, c, sprite);
    if (road) {
      if (sprite == null) {
        canvas.drawRect(
          Rect.fromCenter(center: c, width: 2, height: 2),
          Paint()
            ..color = night ? const Color(0xFF6B6F79) : const Color(0xFFC9CBD0),
        );
      }
      // Street lights on every other corner, lit after dark.
      if (night && (x + y).isEven) {
        final lamp = c.translate(geometry.tileWidth / 4, -2);
        canvas
          ..drawCircle(lamp, 6, Paint()..color = const Color(0x33FFE08A))
          ..drawCircle(lamp, 1.4, Paint()..color = const Color(0xFFFFE9A8));
      }
    }
    if (road) return;
    if (city.underConstruction(x, y)) _siteMarker(canvas, ground);
    if (sprite != null) {
      _sprite(canvas, c, sprite);
      _pathBadge(canvas, c, x, y);
      _needs(canvas, c, x, y);
      _troubleAt(canvas, c, x, y);
      return;
    }

    final civic = City.civicPlots.entries
        .where((e) => e.value == (x, y) && city.civic.contains(e.key))
        .firstOrNull
        ?.key;
    if (civic != null) {
      _civic(canvas, c, civic);
      return;
    }
    final lot = city.lotAt(x, y);
    if (_projects[(x, y)] case final project?) {
      _project(canvas, c, project);
      return;
    }
    if (lot == null) {
      // A few trees on open, unbuilt ground, always the same ones.
      if (!road && _n(x, y, 11) < 0.28) {
        _tree(
          canvas,
          c,
          pine: _n(x, y, 12) < 0.4,
          scale: min(1.0, geometry.tileWidth / 52 * 1.4),
        );
      }
      return;
    }
    if (city.underConstruction(x, y)) {
      _construction(canvas, c);
      return;
    }
    switch (lot.zone) {
      case Zone.home:
        _home(canvas, c, city.sizeOf(x, y), x, y);
      case Zone.shop:
        _shop(canvas, c, city.sizeOf(x, y), x, y);
      case Zone.park:
        _park(canvas, c, city.sizeOf(x, y), x, y);
      case Zone.road:
        break;
      case Zone.market:
        _market(canvas, c, lot.good);
      case Zone.landmark:
        _landmark(canvas, c, lot.landmark, x, y);
      case Zone.service:
        _service(canvas, c, lot.service);
      case Zone.sport:
        _sport(canvas, c, lot.sport);
    }
    _needs(canvas, c, x, y);
    _troubleAt(canvas, c, x, y);
  }

  /// A fire on the building at (x, y), or a thief running round it.
  void _troubleAt(Canvas canvas, Offset c, int x, int y) {
    final now = trouble;
    if (now == null || (now.x, now.y) != (x, y)) return;
    final k = _k;
    if (now.kind == TroubleKind.fire) {
      // Smoke rising and drifting, then the flames in front of it: big
      // enough to spot from across the town.
      for (var i = 0; i < 8; i++) {
        final p = (t * 0.3 + i / 8) % 1;
        canvas.drawCircle(
          c.translate((6 + p * 16) * k, (-30 - p * 70) * k),
          (5 + p * 12) * k,
          Paint()
            ..color = const Color(0xFF5E5E5E).withValues(alpha: 0.55 * (1 - p)),
        );
      }
      const flame = [Color(0xFFFF4D1A), Color(0xFFFF9F1C), Color(0xFFFFD23F)];
      for (var layer = 0; layer < 2; layer++) {
        for (var i = 0; i < 7; i++) {
          final flicker = sin(t * 11 + i * 1.7 + layer);
          final dx = (i - 3) * 4.6 * k;
          final h = (18 + 7 * flicker + (i.isEven ? 7 : 0)) * k *
              (layer == 0 ? 1 : 0.6);
          final base = c.translate(dx, (-8 - (i % 3) * 5 - layer * 10) * k);
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - 3.6 * k, base.dy)
              ..quadraticBezierTo(
                base.dx - 3 * k,
                base.dy - h * 0.6,
                base.dx,
                base.dy - h,
              )
              ..quadraticBezierTo(
                base.dx + 3 * k,
                base.dy - h * 0.6,
                base.dx + 3.6 * k,
                base.dy,
              )
              ..close(),
            Paint()..color = flame[(i + layer) % 3].withValues(alpha: 0.93),
          );
        }
      }
      canvas.drawCircle(
        c.translate(0, -16 * k),
        30 * k,
        Paint()..color = Color(night ? 0x44FF7A1A : 0x22FF7A1A),
      );
      return;
    }
  }

  /// A building site's plot, outlined in pulsing hazard yellow: easy to
  /// find in a busy town, and a reminder that it can still change today.
  void _siteMarker(Canvas canvas, Path ground) {
    final pulse = 0.55 + 0.45 * sin(t * 3);
    canvas
      ..drawPath(
        ground,
        Paint()
          ..color = const Color(0xFFFFC53D).withValues(alpha: 0.18 * pulse),
      )
      ..drawPath(
        ground,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFFFC53D).withValues(alpha: pulse),
      );
  }

  /// The way a building was grown, as a small badge at its foot: 🌻 for a
  /// garden, ☕ for a café.
  void _pathBadge(Canvas canvas, Offset c, int x, int y) {
    final path = city.lotAt(x, y)?.upgrades.lastOrNull?.path;
    if (path == null) return;
    final k = _k;
    final at = c.translate(-geometry.tileWidth * 0.28, -2 * k);
    canvas.drawCircle(
      at,
      5 * k,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    final painter = _symbol(pathEmoji(path), 6.5 * k);
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  /// How much smaller than the plot size they were drawn at the
  /// hand-drawn buildings are: the same as the 3D pictures beside them.
  double get _k => geometry.tileWidth / 44;

  /// A thief running round the home he has picked, drawn over the town
  /// so no building hides him.
  void _thief(Canvas canvas) {
    final now = trouble;
    if (now == null || now.kind != TroubleKind.thief) return;
    final c = geometry.at(now.x, now.y);
    final k = _k;
    // A thief in a striped jumper and a mask, a sack over his shoulder,
    // running round and round the home and now and then stopping to
    // laugh.
    final k2 = k * 2.2;
    final a = t * 1.8;
    final pause = sin(t * 0.7) > 0.85;
    final angle = pause ? (t * 0.7).floorToDouble() : a;
    final p = c.translate(
      cos(angle) * geometry.tileWidth * 0.42,
      sin(angle) * geometry.tileHeight * 0.42 + 2 * k2,
    );
    final hop = pause ? sin(t * 14).abs() * 2.5 * k2 : 0.0;
    canvas
      ..drawOval(
        Rect.fromCenter(center: p, width: 5 * k2, height: 2 * k2),
        Paint()..color = const Color(0x44000000),
      )
      ..drawRect(
        Rect.fromLTWH(p.dx - 1.4 * k2, p.dy - 7 * k2 - hop, 2.8 * k2, 5 * k2),
        Paint()..color = const Color(0xFF222222),
      );
    for (var i = 0; i < 2; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          p.dx - 1.4 * k2,
          p.dy - (6.2 - i * 2) * k - hop,
          2.8 * k2,
          0.8 * k2,
        ),
        Paint()..color = Colors.white,
      );
    }
    canvas
      ..drawCircle(
        p.translate(0, -8.6 * k2 - hop),
        1.5 * k2,
        Paint()..color = const Color(0xFFF1C9A5),
      )
      ..drawRect(
        Rect.fromLTWH(p.dx - 1.6 * k2, p.dy - 9.2 * k2 - hop, 3.2 * k2, 0.9 * k2),
        Paint()..color = const Color(0xFF111111),
      )
      ..drawCircle(
        p.translate(2.4 * k2, -7.4 * k2 - hop),
        1.8 * k2,
        Paint()..color = const Color(0xFFB08D57),
      );
  }

  /// A small bubble over a building that has earned a size and waits for
  /// a service: the child can see what to build, and where.
  void _needs(Canvas canvas, Offset c, int x, int y) {
    final missing = _missing[(x, y)];
    if (missing == null) return;
    final k = _k;
    final bob = sin(t * 2 + x + y) * 1.2 * k;
    final at = c.translate(0, -geometry.tileHeight * 1.5 + bob);
    canvas.drawCircle(
      at,
      6.5 * k,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: serviceEmoji(missing.first),
        style: TextStyle(fontSize: 8 * k),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  /// What keeps the town going, drawn until the kits have pictures of
  /// them.
  void _service(Canvas canvas, Offset c, Service? which) {
    final k = _k;
    Offset o(double dx, double dy) => c.translate(dx * k, dy * k);
    switch (which) {
      case Service.power:
        // A wind turbine, turning.
        final hub = o(0, -34);
        canvas.drawLine(
          c,
          hub,
          Paint()
            ..color = const Color(0xFFE9ECEF)
            ..strokeWidth = 2 * k,
        );
        final blade = Paint()
          ..color = const Color(0xFFF8F9FA)
          ..strokeWidth = 1.6 * k
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final a = t * 2 + i * 2 * pi / 3;
          canvas.drawLine(
            hub,
            hub + Offset(cos(a) * 14 * k, sin(a) * 14 * k),
            blade,
          );
        }
        canvas.drawCircle(hub, 2 * k, Paint()..color = const Color(0xFFADB5BD));
      case Service.water:
        // A water tower: a tank on legs.
        final leg = Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 1.4 * k;
        for (final dx in [-6.0, 6.0]) {
          canvas.drawLine(o(dx, 2), o(dx * 0.6, -20), leg);
        }
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: o(0, -25), width: 16 * k, height: 11 * k),
              Radius.circular(4 * k),
            ),
            Paint()
              ..color = night
                  ? const Color(0xFF2B5C86)
                  : const Color(0xFF4FA3D9),
          )
          ..drawRect(
            Rect.fromCenter(center: o(0, -31), width: 10 * k, height: 2.5 * k),
            Paint()..color = const Color(0xFF2F6F98),
          );
      case Service.fire:
        final top = _box(
          canvas,
          c,
          14 * k,
          const Color(0xFFE05A4F),
          const Color(0xFFC0392B),
          const Color(0xFFA93226),
          windows: false,
        );
        canvas
          ..drawRect(
            Rect.fromLTWH(top.dx + 2 * k, top.dy - 8 * k, 8 * k, 7 * k),
            Paint()..color = const Color(0xFFF5F5F5),
          )
          ..drawRect(
            Rect.fromLTWH(top.dx - 3 * k, top.dy - 26 * k, 5 * k, 14 * k),
            Paint()..color = const Color(0xFFC0392B),
          );
      case Service.clinic:
        final top = _box(
          canvas,
          c,
          15 * k,
          const Color(0xFFF8F9FA),
          const Color(0xFFE9ECEF),
          const Color(0xFFD5D9DD),
          windows: false,
        );
        final cross = Paint()..color = const Color(0xFFE03131);
        final mid = top.translate(0, -20 * k);
        canvas
          ..drawRect(
            Rect.fromCenter(center: mid, width: 7 * k, height: 2.4 * k),
            cross,
          )
          ..drawRect(
            Rect.fromCenter(center: mid, width: 2.4 * k, height: 7 * k),
            cross,
          );
      case Service.police:
        final top = _box(
          canvas,
          c,
          14 * k,
          const Color(0xFF4C6EF5),
          const Color(0xFF3B5BDB),
          const Color(0xFF364FC7),
        );
        final blink = (t * 2).floor().isEven;
        canvas.drawRect(
          Rect.fromCenter(
            center: top.translate(0, -16 * k),
            width: 6 * k,
            height: 2 * k,
          ),
          Paint()
            ..color = blink ? const Color(0xFFFF4D4D) : const Color(0xFF4DABF7),
        );
      case Service.bus:
        // A shelter by the street, and its sign.
        canvas
          ..drawRect(
            Rect.fromLTWH(c.dx - 8 * k, c.dy - 12 * k, 16 * k, 2 * k),
            Paint()..color = const Color(0xFF1C7ED6),
          )
          ..drawRect(
            Rect.fromLTWH(c.dx - 7 * k, c.dy - 10 * k, 14 * k, 8 * k),
            Paint()..color = const Color(0x6699CCFF),
          )
          ..drawLine(
            o(10, 0),
            o(10, -16),
            Paint()
              ..color = const Color(0xFF495057)
              ..strokeWidth = 1 * k,
          )
          ..drawCircle(
            o(10, -17),
            3 * k,
            Paint()..color = const Color(0xFFFFD43B),
          );
      case null:
        break;
    }
  }

  /// A sports building, drawn until its picture is there.
  void _sport(Canvas canvas, Offset c, Sport? which) {
    final ground = _diamond(c);
    switch (which) {
      case Sport.pitch:
        canvas
          ..drawPath(ground, Paint()..color = const Color(0xFF3FA34D))
          ..drawPath(
            ground,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white,
          );
      case Sport.pool:
        canvas
          ..drawPath(ground, Paint()..color = const Color(0xFFE9ECEF))
          ..save()
          ..translate(c.dx, c.dy)
          ..scale(0.75)
          ..translate(-c.dx, -c.dy)
          ..drawPath(ground, Paint()..color = const Color(0xFF4DC3FF))
          ..restore();
      case Sport.hall:
        _box(
          canvas,
          c,
          16 * _k,
          const Color(0xFFFFA94D),
          const Color(0xFFF08C00),
          const Color(0xFFD9480F),
        );
      case null:
        break;
    }
  }

  /// What the family built together: a statue, a clock tower, a Ferris
  /// wheel. The same in every child's city.
  void _project(Canvas canvas, Offset c, FamilyProject project) {
    final k = _k;
    Offset o(double dx, double dy) => c.translate(dx * k, dy * k);
    switch (project) {
      case FamilyProject.statue:
        canvas
          ..drawRect(
            Rect.fromCenter(center: o(0, -4), width: 12 * k, height: 6 * k),
            Paint()..color = const Color(0xFFBDB6AA),
          )
          ..drawRect(
            Rect.fromCenter(center: o(0, -14), width: 5 * k, height: 14 * k),
            Paint()..color = const Color(0xFFB08D57),
          )
          ..drawCircle(
            o(0, -23),
            3.2 * k,
            Paint()..color = const Color(0xFFB08D57),
          );
      case FamilyProject.clockTower:
        final top = _box(
          canvas,
          c,
          34 * k,
          const Color(0xFFD9C7A7),
          const Color(0xFFC4AE88),
          const Color(0xFFAE9670),
          windows: false,
        );
        final face = top.translate(-5 * k, -28 * k);
        canvas.drawCircle(face, 4 * k, Paint()..color = Colors.white);
        final hand = Paint()
          ..color = const Color(0xFF343A40)
          ..strokeWidth = 0.8 * k;
        final a = t / 10;
        canvas
          ..drawLine(face, face + Offset(cos(a), sin(a)) * 3.2 * k, hand)
          ..drawLine(
            face,
            face + Offset(cos(a / 12), sin(a / 12)) * 2 * k,
            hand,
          );
      case FamilyProject.ferrisWheel:
        final hub = o(0, -26);
        final rim = Paint()
          ..color = const Color(0xFFADB5BD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * k;
        canvas
          ..drawLine(o(-8, 0), hub, rim)
          ..drawLine(o(8, 0), hub, rim)
          ..drawCircle(hub, 18 * k, rim);
        const cars = [
          Color(0xFFE64980),
          Color(0xFF4DABF7),
          Color(0xFFFFD43B),
          Color(0xFF69DB7C),
        ];
        for (var i = 0; i < 8; i++) {
          final a = t * 0.3 + i * pi / 4;
          final at = hub + Offset(cos(a), sin(a)) * 18 * k;
          canvas.drawRect(
            Rect.fromCenter(
              center: at.translate(0, 3 * k),
              width: 5 * k,
              height: 4 * k,
            ),
            Paint()..color = cars[i % 4],
          );
        }
    }
  }

  /// A whale surfacing in the lake, blowing now and then.
  void _whale(Canvas canvas, Offset c) {
    final rise = sin(t * 0.8);
    if (rise < -0.3) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -1 - rise * 2),
        width: 18,
        height: 6,
      ),
      Paint()..color = const Color(0xFF34495E),
    );
    if (rise > 0.6) {
      final spout = Paint()..color = Colors.white.withValues(alpha: 0.8);
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          c.translate(-3 + (i - 2) * 1.6, -8 - i % 2 * 3),
          1.4,
          spout,
        );
      }
    }
  }

  /// A balloon race over the town: five of them, all colours.
  void _balloonRace(Canvas canvas) {
    final r = city.radius.toDouble();
    const m = City.centre;
    final top = geometry.at(m - r, m - r).dy - 20;
    final left = geometry.at(m - r, m + r).dx - 20;
    final span = geometry.at(m + r, m - r).dx + 20 - left;
    const colours = [
      Color(0xFFE4572E),
      Color(0xFF4DABF7),
      Color(0xFFFFD43B),
      Color(0xFF9775FA),
      Color(0xFF51CF66),
    ];
    for (var i = 0; i < colours.length; i++) {
      final x = left + ((t * (6 + i) + i * span / 5) % span);
      final y = top + i * 14 + sin(t * 0.5 + i) * 5;
      canvas
        ..drawCircle(Offset(x, y), 7, Paint()..color = colours[i])
        ..drawRect(
          Rect.fromLTWH(x - 2, y + 10, 4, 3),
          Paint()..color = const Color(0xFF8A6246),
        );
    }
  }

  /// Shooting stars, one every few seconds.
  void _meteors(Canvas canvas) {
    final r = city.radius.toDouble();
    const m = City.centre;
    final top = geometry.at(m - r, m - r).dy - 60;
    final left = geometry.at(m - r, m + r).dx;
    final span = geometry.at(m + r, m - r).dx - left;
    for (var i = 0; i < 3; i++) {
      final p = (t / 3 + i / 3) % 1;
      if (p > 0.3) continue;
      final q = p / 0.3;
      final start = Offset(left + span * _hash(i, (t / 3).floor(), 90), top);
      final head = start + Offset(q * 60, q * 30);
      canvas.drawLine(
        head - const Offset(14, 7),
        head,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 1 - q),
            ],
          ).createShader(Rect.fromPoints(head - const Offset(14, 7), head))
          ..strokeWidth = 1.4,
      );
    }
  }

  /// A trading house: a market hall with a striped awning and crates of
  /// what it makes stacked out front.
  void _market(Canvas canvas, Offset c, Good? good) {
    _box(
      canvas,
      c,
      16,
      const Color(0xFFF3E3C3),
      const Color(0xFFD8B27A),
      const Color(0xFFC39A5E),
      windows: false,
    );
    final w = geometry.tileWidth / 2 - 4;
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(c.dx - w + 2 + i * (w / 2), c.dy - 12, w / 4, 4),
        Paint()..color = i.isEven ? const Color(0xFFE4572E) : Colors.white,
      );
    }
    final crate = switch (good) {
      Good.fish => const Color(0xFF6EC1E4),
      Good.wood => const Color(0xFF8A6246),
      Good.stone => const Color(0xFF9EA3AA),
      Good.wool => const Color(0xFFF2F0EA),
      Good.honey => const Color(0xFFF2B233),
      null => const Color(0xFFB08D5B),
    };
    canvas
      ..drawRect(
        Rect.fromLTWH(c.dx + 3, c.dy - 3, 5, 4),
        Paint()..color = crate,
      )
      ..drawRect(
        Rect.fromLTWH(c.dx + 8, c.dy - 1, 5, 4),
        Paint()..color = crate,
      )
      ..drawRect(
        Rect.fromLTWH(c.dx - 1, c.dy - 23, 2, 7),
        Paint()..color = const Color(0xFF555555),
      )
      ..drawRect(
        Rect.fromLTWH(c.dx, c.dy - 23 + sin(t * 3), 7, 5),
        Paint()..color = crate,
      );
  }

  /// The special buildings, each one of a kind in the city.
  void _landmark(Canvas canvas, Offset c, Landmark? which, int x, int y) {
    switch (which) {
      case Landmark.harbour:
        // A jetty out over the water, a lighthouse, and a boat tied up.
        final plank = Paint()..color = const Color(0xFF8A6246);
        canvas.drawPath(_diamond(c), Paint()..color = const Color(0xFFCFC8BC));
        for (var i = -2; i <= 2; i++) {
          canvas.drawRect(
            Rect.fromLTWH(c.dx - 12 + i * 2, c.dy - 1 + i, 14, 2),
            plank,
          );
        }
        // A slim lighthouse, red and white, lit at night.
        final base = c.translate(7, -1);
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              base.dx - 3 + i * 0.3,
              base.dy - 6 - i * 6,
              6 - i * 0.6,
              6,
            ),
            Paint()
              ..color = i.isEven
                  ? const Color(0xFFD64545)
                  : (night ? const Color(0xFFB8BCC6) : Colors.white),
          );
        }
        final lamp = night && (t * 1.5).floor().isEven;
        canvas
          ..drawRect(
            Rect.fromLTWH(base.dx - 2.5, base.dy - 33, 5, 3),
            Paint()..color = const Color(0xFF39414D),
          )
          ..drawCircle(
            base.translate(0, -34),
            2.4,
            Paint()
              ..color = lamp
                  ? const Color(0xFFFFE066)
                  : const Color(0xFFF2F2F2),
          );
        if (lamp) {
          canvas.drawCircle(
            base.translate(0, -34),
            7,
            Paint()..color = const Color(0x55FFE066),
          );
        }
        // A boat tied up at the end of the jetty.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 16, c.dy + 3)
            ..lineTo(c.dx - 8, c.dy + 3)
            ..lineTo(c.dx - 10, c.dy + 6)
            ..lineTo(c.dx - 14, c.dy + 6)
            ..close(),
          Paint()..color = const Color(0xFF4A90D9),
        );
      case Landmark.castle:
        const stone = [Color(0xFFD9D4CC), Color(0xFFB5AEA3), Color(0xFF9C9488)];
        _box(canvas, c, 20, stone[0], stone[1], stone[2], windows: false);
        for (final dx in [-12.0, 12.0]) {
          final tower = c.translate(dx, -1);
          canvas
            ..drawRect(
              Rect.fromLTWH(tower.dx - 4, tower.dy - 34, 8, 30),
              Paint()
                ..color = night
                    ? Color.lerp(stone[1], const Color(0xFF141B33), 0.6)!
                    : stone[1],
            )
            ..drawPath(
              Path()
                ..moveTo(tower.dx - 5, tower.dy - 34)
                ..lineTo(tower.dx, tower.dy - 44)
                ..lineTo(tower.dx + 5, tower.dy - 34)
                ..close(),
              Paint()..color = const Color(0xFF4A6FA5),
            )
            ..drawRect(
              Rect.fromLTWH(tower.dx, tower.dy - 52 + sin(t * 3 + dx), 6, 4),
              Paint()..color = const Color(0xFFE4572E),
            )
            ..drawRect(
              Rect.fromLTWH(tower.dx - 0.5, tower.dy - 52, 1, 8),
              Paint()..color = const Color(0xFF555555),
            );
        }
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 3, c.dy - 8, 6, 8),
          Paint()..color = const Color(0xFF6B4A2B),
        );
      case Landmark.zoo:
        canvas.drawPath(
          _diamond(c),
          Paint()
            ..color = night ? const Color(0xFF3C5A2E) : const Color(0xFFB8D98A),
        );
        _tree(canvas, c.translate(-8, -1), scale: 0.8);
        // A giraffe, its head bobbing over the fence.
        final bob = sin(t * 1.2) * 1.5;
        final spot = Paint()..color = const Color(0xFFE9B949);
        canvas
          ..drawRect(Rect.fromLTWH(c.dx + 2, c.dy - 6, 8, 5), spot)
          ..drawRect(Rect.fromLTWH(c.dx + 8, c.dy - 20 + bob, 2.5, 15), spot)
          ..drawRect(Rect.fromLTWH(c.dx + 8, c.dy - 22 + bob, 5, 3), spot);
        final fence = Paint()
          ..color = const Color(0xFF8A6246)
          ..strokeWidth = 1;
        final w = geometry.tileWidth / 2 - 2, h = geometry.tileHeight / 2 - 1;
        canvas
          ..drawLine(c.translate(-w, 0), c.translate(0, h), fence)
          ..drawLine(c.translate(0, h), c.translate(w, 0), fence);
      case Landmark.stadium:
        canvas
          ..drawOval(
            Rect.fromCenter(center: c.translate(0, -4), width: 30, height: 18),
            Paint()
              ..color = night
                  ? const Color(0xFF5A6070)
                  : const Color(0xFFBFC5CF),
          )
          ..drawOval(
            Rect.fromCenter(center: c.translate(0, -5), width: 20, height: 10),
            Paint()..color = const Color(0xFF4DAF5B),
          )
          ..drawLine(
            c.translate(0, -10),
            c.translate(0, 0),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 0.8,
          );
        if (night) {
          for (final dx in [-14.0, 14.0]) {
            canvas.drawCircle(
              c.translate(dx, -16),
              2,
              Paint()..color = const Color(0xFFFFF3B0),
            );
          }
        }
      case Landmark.bakery:
        _box(
          canvas,
          c,
          16,
          const Color(0xFFF6E7D2),
          const Color(0xFFE2C29A),
          const Color(0xFFCCA676),
        );
        _pitched(canvas, c, 16, const Color(0xFF8A5A3B), 9);
        // The sign: a golden pretzel, and a smoking chimney.
        canvas.drawCircle(
          c.translate(-8, -6),
          3,
          Paint()
            ..color = const Color(0xFFD99A3E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final puff = (t * 0.5 + _n(x, y, 61)) % 1;
        canvas.drawCircle(
          c.translate(7 + puff * 3, -30 - puff * 10),
          1.5 + puff * 2.5,
          Paint()..color = Colors.white.withValues(alpha: 0.6 * (1 - puff)),
        );
      case null:
        _box(
          canvas,
          c,
          18,
          const Color(0xFFE8E0F0),
          const Color(0xFFBFB0D8),
          const Color(0xFFA592C6),
        );
    }
  }

  /// A box standing on a plot: left face, right face, top, and windows.
  Offset _box(
    Canvas canvas,
    Offset c,
    double h,
    Color top,
    Color left,
    Color right, {
    bool windows = true,
  }) {
    // Parameters are reassigned for night below.
    // ignore: parameter_assignments
    final w = geometry.tileWidth / 2 - 4, d = geometry.tileHeight / 2 - 2;
    // At night the walls fall into shadow, so the lit windows are what you
    // see — the way a town looks from a hill in the evening.
    if (night) {
      top = Color.lerp(top, const Color(0xFF141B33), 0.55)!;
      left = Color.lerp(left, const Color(0xFF141B33), 0.6)!;
      right = Color.lerp(right, const Color(0xFF141B33), 0.68)!;
    }
    canvas
      ..drawPath(
        Path()
          ..moveTo(c.dx - w, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx, c.dy + d - h)
          ..lineTo(c.dx - w, c.dy - h)
          ..close(),
        Paint()..color = left,
      )
      ..drawPath(
        Path()
          ..moveTo(c.dx + w, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx, c.dy + d - h)
          ..lineTo(c.dx + w, c.dy - h)
          ..close(),
        Paint()..color = right,
      )
      ..drawPath(
        Path()
          ..moveTo(c.dx, c.dy - d - h)
          ..lineTo(c.dx + w, c.dy - h)
          ..lineTo(c.dx, c.dy + d - h)
          ..lineTo(c.dx - w, c.dy - h)
          ..close(),
        Paint()..color = top,
      );
    if (windows) {
      final lit = Paint()
        ..color = night
            ? const Color(0xFFFFD66B)
            : Colors.white.withValues(alpha: 0.55);
      for (var f = 6.0; f < h - 2; f += 7) {
        canvas
          ..drawRect(Rect.fromLTWH(c.dx - w + 4, c.dy - f - 3, 3, 3), lit)
          ..drawRect(Rect.fromLTWH(c.dx - w + 10, c.dy - f, 3, 3), lit)
          ..drawRect(Rect.fromLTWH(c.dx + 5, c.dy - f, 3, 3), lit)
          ..drawRect(Rect.fromLTWH(c.dx + 11, c.dy - f - 3, 3, 3), lit);
      }
    }
    return c;
  }

  void _home(Canvas canvas, Offset c, int size, int x, int y) {
    const heights = [10.0, 20.0, 34.0, 54.0];
    // A few shades for each size, and each home's shade and height fixed
    // by where it stands, so a street has some variety and no building
    // looks different the next time the city is opened.
    const palettes = [
      [
        [Color(0xFFF2D8B8), Color(0xFFD9A77C), Color(0xFFC98F62)],
        [Color(0xFFF4E6CC), Color(0xFFE2C196), Color(0xFFCCA274)],
        [Color(0xFFEFD3C9), Color(0xFFD6A391), Color(0xFFC28A76)],
      ],
      [
        [Color(0xFFF4E3C1), Color(0xFFE0B983), Color(0xFFC99B62)],
        [Color(0xFFE6EEDC), Color(0xFFB9CBA1), Color(0xFF9DB384)],
        [Color(0xFFF3DAD6), Color(0xFFD9A7A0), Color(0xFFC28B83)],
      ],
      [
        [Color(0xFFDDE6EE), Color(0xFFA9B8C7), Color(0xFF8FA0B2)],
        [Color(0xFFEDE3D6), Color(0xFFC6B29B), Color(0xFFAE9880)],
        [Color(0xFFE2E8DE), Color(0xFFAFBDA5), Color(0xFF94A48A)],
      ],
      [
        [Color(0xFFCFE3F2), Color(0xFF86A8C8), Color(0xFF6E91B4)],
        [Color(0xFFD8DCE8), Color(0xFF9CA3BD), Color(0xFF8189A6)],
        [Color(0xFFD5EAE6), Color(0xFF8DBDB4), Color(0xFF71A69B)],
      ],
    ];
    final shade = palettes[size][(_n(x, y, 21) * 3).floor() % 3];
    final h =
        heights[size] +
        (size == 0 ? 0 : (_n(x, y, 22) - 0.5) * heights[size] * 0.35);
    final p = shade;
    _box(canvas, c, h, p[0], p[1], p[2]);
    final roof = c.translate(0, -h);
    final style = (_n(x, y, 23) * 4).floor() % 4;
    const roofs = [
      Color(0xFFB84A3A), // red tiles
      Color(0xFF5E6470), // slate
      Color(0xFF3F6E9E), // blue
      Color(0xFF4F7D4A), // green
    ];
    switch (size) {
      case 0:
        // A cottage: a pitched roof in one of four colours, and now and
        // then a chimney with smoke.
        _pitched(canvas, c, h, roofs[style], 11);
        if (_n(x, y, 24) < 0.45) {
          canvas.drawRect(
            Rect.fromLTWH(roof.dx + 5, roof.dy - 10, 3, 6),
            Paint()..color = const Color(0xFF7A5A48),
          );
          if (!night) {
            final puff = (t * 0.6 + _n(x, y, 25)) % 1;
            canvas.drawCircle(
              roof.translate(6.5 + puff * 3, -12 - puff * 10),
              1.5 + puff * 2,
              Paint()..color = Colors.white.withValues(alpha: 0.6 * (1 - puff)),
            );
          }
        }
      case 1:
        // A house: pitched or flat, by the street's own dice.
        if (style < 2) _pitched(canvas, c, h, roofs[(style + 2) % 4], 8);
      case 2:
        // Apartments: balconies, or a garden on the roof.
        if (style.isEven) {
          final rail = Paint()..color = Colors.white.withValues(alpha: 0.7);
          for (var f = 10.0; f < h - 4; f += 9) {
            canvas.drawRect(
              Rect.fromLTWH(c.dx + 3, c.dy - f + 3, 10, 1.4),
              rail,
            );
          }
        } else {
          canvas
            ..drawCircle(
              roof.translate(-4, -2),
              3,
              Paint()..color = const Color(0xFF3E8E4A),
            )
            ..drawCircle(
              roof.translate(3, -1),
              2.5,
              Paint()..color = const Color(0xFF4FA35A),
            );
        }
      default:
        // A tower gets something on its roof: a mast, a water tank, a
        // spire or a helipad.
        switch (style) {
          case 0:
            canvas.drawRect(
              Rect.fromLTWH(roof.dx - 1, roof.dy - 12, 2, 10),
              Paint()..color = const Color(0xFF7A8290),
            );
            if (night && (t * 2).floor().isEven) {
              canvas.drawCircle(
                roof.translate(0, -13),
                1.6,
                Paint()..color = const Color(0xFFFF4D4D),
              );
            }
          case 1:
            canvas.drawRect(
              Rect.fromLTWH(roof.dx - 4, roof.dy - 7, 8, 5),
              Paint()..color = const Color(0xFF9A7B5B),
            );
          case 2:
            canvas.drawPath(
              Path()
                ..moveTo(roof.dx - 5, roof.dy - 1)
                ..lineTo(roof.dx, roof.dy - 18)
                ..lineTo(roof.dx + 5, roof.dy - 1)
                ..close(),
              Paint()..color = const Color(0xFF8FA0B2),
            );
          default:
            canvas
              ..drawOval(
                Rect.fromCenter(center: roof, width: 16, height: 7),
                Paint()..color = const Color(0xFF4A505A),
              )
              ..drawCircle(roof, 2, Paint()..color = const Color(0xFFF2C94C));
        }
    }
  }

  /// A pitched roof [rise] high on a box [h] tall.
  void _pitched(Canvas canvas, Offset c, double h, Color colour, double rise) {
    final w = geometry.tileWidth / 2 - 4;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w, c.dy - h)
        ..lineTo(c.dx, c.dy - h - rise)
        ..lineTo(c.dx + w, c.dy - h)
        ..lineTo(c.dx, c.dy - h + geometry.tileHeight / 2 - 2)
        ..close(),
      Paint()
        ..color = night
            ? Color.lerp(colour, const Color(0xFF141B33), 0.55)!
            : colour,
    );
  }

  void _shop(Canvas canvas, Offset c, int size, int x, int y) {
    const heights = [12.0, 18.0, 26.0];
    _box(
      canvas,
      c,
      heights[size],
      const Color(0xFFF7E7A1),
      const Color(0xFFE8B84A),
      const Color(0xFFD29C2E),
    );
    const awnings = [Color(0xFFE4572E), Color(0xFF4A90D9), Color(0xFF43AA8B)];
    canvas.drawRect(
      Rect.fromLTWH(
        c.dx - geometry.tileWidth / 2 + 5,
        c.dy - 9,
        geometry.tileWidth / 2 - 6,
        3,
      ),
      Paint()..color = awnings[(_n(x, y, 3) * 3).floor() % 3],
    );
  }

  /// A park, as grown: a lawn and a sapling, trees and a bench, then a
  /// pond, a playground or flower beds, then a big park with a pavilion.
  /// Which of the three it becomes is the plot's own.
  void _park(Canvas canvas, Offset c, int size, int x, int y) {
    // The lawn gets richer as the park grows, and paths come with the
    // bigger ones: a park that has been looked after for a while looks it.
    const lawns = [
      Color(0xFF8ACB72),
      Color(0xFF6CC064),
      Color(0xFF5DBB63),
      Color(0xFF4DAF5B),
    ];
    canvas.drawPath(
      _diamond(c),
      Paint()..color = night ? const Color(0xFF2E6B3A) : lawns[size],
    );
    if (size >= 2) {
      final gravel = Paint()
        ..color = night ? const Color(0xFF5A5446) : const Color(0xFFE3D6B4)
        ..strokeWidth = max(1.2, geometry.tileHeight / 9);
      final w = geometry.tileWidth / 2, h = geometry.tileHeight / 2;
      canvas.drawLine(
        c.translate(-w * 0.5, -h * 0.5),
        c.translate(w * 0.5, h * 0.5),
        gravel,
      );
      if (size == 3) {
        canvas.drawLine(
          c.translate(w * 0.5, -h * 0.5),
          c.translate(-w * 0.5, h * 0.5),
          gravel,
        );
      }
    }
    // Drawn to fit its own plot, whatever the zoom: at a phone's size the
    // trees used to stand on the neighbours and hide the pond.
    final k = min(1.0, geometry.tileWidth / 52 * 1.4);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(k);
    const o = Offset.zero;
    final kind = (_n(x, y, 31) * 3).floor() % 3;
    final flip = _n(x, y, 32) < 0.5 ? -1.0 : 1.0;
    void flowers(Offset at, int n) {
      const petals = [Color(0xFFFF7EB3), Color(0xFFFFD166), Color(0xFFB39DFF)];
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(
          at.translate((i % 3 - 1) * 4.0, (i ~/ 3) * 3.0),
          1.8,
          Paint()..color = petals[(i + kind) % 3],
        );
      }
    }

    switch (size) {
      case 0:
        _tree(canvas, o.translate(4 * flip, 3), scale: 0.55);
        flowers(o.translate(-6 * flip, 2), 3);
      case 1:
        _tree(canvas, o.translate(-8 * flip, 1));
        _tree(canvas, o.translate(8 * flip, -2), pine: kind == 2);
        _bench(canvas, o.translate(0, 6));
      case 2:
        switch (kind) {
          case 0:
            _pond(canvas, o.translate(5 * flip, 3), 16, 8);
          case 1:
            _playground(canvas, o.translate(4 * flip, 3));
          default:
            flowers(o.translate(4 * flip, 0), 9);
        }
        _tree(canvas, o.translate(-11 * flip, 0));
      default:
        _pond(canvas, o.translate(-7 * flip, 4), 14, 7);
        _tree(canvas, o.translate(11 * flip, 1));
        _tree(canvas, o.translate(-13 * flip, -3), pine: true);
        _pavilion(canvas, o.translate(5 * flip, -2));
        flowers(o.translate(1, 8), 3);
    }
    canvas.restore();
  }

  void _bench(Canvas canvas, Offset at) {
    final wood = Paint()..color = const Color(0xFF8A6246);
    canvas
      ..drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 3, 8, 2), wood)
      ..drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 1, 1, 2), wood)
      ..drawRect(Rect.fromLTWH(at.dx + 3, at.dy - 1, 1, 2), wood);
  }

  void _pond(Canvas canvas, Offset at, double w, double h) {
    canvas
      ..drawOval(
        Rect.fromCenter(center: at, width: w + 3, height: h + 2),
        Paint()..color = const Color(0xFFCFC8BC),
      )
      ..drawOval(
        Rect.fromCenter(center: at, width: w, height: h),
        Paint()
          ..color = night ? const Color(0xFF2B4D6E) : const Color(0xFF6EC1E4),
      );
    // A duck, going round.
    if (!night) {
      final a = t * 0.8;
      canvas.drawCircle(
        at.translate(cos(a) * w * 0.28, sin(a) * h * 0.25),
        1.5,
        Paint()..color = const Color(0xFFFFF3B0),
      );
    }
  }

  void _playground(Canvas canvas, Offset at) {
    final frame = Paint()
      ..color = const Color(0xFFE4572E)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(at.translate(-6, 0), at.translate(-4, -10), frame)
      ..drawLine(at.translate(2, 0), at.translate(0, -10), frame)
      ..drawLine(at.translate(-4, -10), at.translate(0, -10), frame);
    final swing = sin(t * 2.4) * 2;
    canvas
      ..drawLine(
        at.translate(-2, -10),
        at.translate(-2 + swing, -4),
        Paint()..color = const Color(0xFF555555),
      )
      ..drawRect(
        Rect.fromLTWH(at.dx - 3.5 + swing, at.dy - 4, 3, 1.5),
        Paint()..color = const Color(0xFF4A90D9),
      );
    // A slide.
    canvas.drawLine(
      at.translate(5, -7),
      at.translate(10, 0),
      Paint()
        ..color = const Color(0xFFF2C94C)
        ..strokeWidth = 2,
    );
  }

  void _pavilion(Canvas canvas, Offset at) {
    final post = Paint()..color = Colors.white;
    canvas
      ..drawRect(Rect.fromLTWH(at.dx - 5, at.dy - 8, 1.5, 8), post)
      ..drawRect(Rect.fromLTWH(at.dx + 3.5, at.dy - 8, 1.5, 8), post)
      ..drawPath(
        Path()
          ..moveTo(at.dx - 7, at.dy - 8)
          ..lineTo(at.dx, at.dy - 14)
          ..lineTo(at.dx + 7, at.dy - 8)
          ..close(),
        Paint()
          ..color = night ? const Color(0xFF6B3A33) : const Color(0xFFB84A3A),
      );
  }

  /// A plot of the lake: shallow at the edge, ripples moving across, and
  /// on a lake big enough a little boat. Faint where the town has not
  /// reached yet, so a child can see what lies ahead.
  void _water(Canvas canvas, Offset c, int x, int y, {required bool open}) {
    final deep = night ? const Color(0xFF1F3F63) : const Color(0xFF4FA8D8);
    canvas.drawPath(
      _diamond(c),
      Paint()..color = open ? deep : deep.withValues(alpha: 0.35),
    );
    if (!open) return;
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: night ? 0.18 : 0.45)
      ..strokeWidth = 1;
    final shift = ((t * 0.5 + _n(x, y, 41)) % 1) * 8 - 4;
    canvas
      ..drawLine(
        c.translate(-6 + shift, -1),
        c.translate(-1 + shift, -1),
        ripple,
      )
      ..drawLine(c.translate(1 - shift, 2), c.translate(6 - shift, 2), ripple);
    final first = city.water.reduce(
      (a, b) => (a.$1 + a.$2) <= (b.$1 + b.$2) ? a : b,
    );
    if (city.water.length >= 4 && first == (x, y)) {
      final bob = sin(t * 1.5) * 1.2;
      canvas
        ..drawPath(
          Path()
            ..moveTo(c.dx - 5, c.dy + bob)
            ..lineTo(c.dx + 5, c.dy + bob)
            ..lineTo(c.dx + 3, c.dy + 3 + bob)
            ..lineTo(c.dx - 3, c.dy + 3 + bob)
            ..close(),
          Paint()..color = const Color(0xFF8A6246),
        )
        ..drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 9 + bob)
            ..lineTo(c.dx, c.dy + bob)
            ..lineTo(c.dx + 5, c.dy + bob)
            ..close(),
          Paint()..color = Colors.white,
        );
    }
  }

  void _tree(Canvas canvas, Offset c, {bool pine = false, double scale = 1}) {
    final leaf = Paint()
      ..color = night
          ? const Color(0xFF23522F)
          : (pine ? const Color(0xFF2F7A45) : const Color(0xFF3E8E4A));
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 1, c.dy - 12 * scale, 2, 8 * scale),
      Paint()..color = const Color(0xFF6B4A2B),
    );
    // A breeze: each tree a little out of step with the next.
    final sway = sin(t * 1.3 + c.dx * 0.07 + c.dy * 0.05) * 1.2 * scale;
    if (pine) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 6 * scale, c.dy - 8 * scale)
          ..lineTo(c.dx + sway, c.dy - 24 * scale)
          ..lineTo(c.dx + 6 * scale, c.dy - 8 * scale)
          ..close(),
        leaf,
      );
    } else {
      canvas.drawCircle(c.translate(sway, -15 * scale), 7 * scale, leaf);
    }
  }

  void _construction(Canvas canvas, Offset c) {
    // Scaffolding and a crane: being built today, and can still change.
    final frame = Paint()
      ..color = const Color(0xFFF2A93B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas
      ..drawRect(Rect.fromLTWH(c.dx - 9, c.dy - 16, 18, 14), frame)
      ..drawLine(c.translate(-9, -9), c.translate(9, -9), frame)
      ..drawLine(c.translate(6, -2), c.translate(6, -30), frame)
      ..drawLine(c.translate(6, -30), c.translate(-8, -30), frame);
    final swing = sin(t * 2) * 3;
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 9 + swing, c.dy - 27, 4, 4),
      Paint()..color = const Color(0xFF8B8E94),
    );
  }

  void _civic(Canvas canvas, Offset c, Civic building) {
    switch (building) {
      case Civic.hall:
        _box(
          canvas,
          c,
          24,
          const Color(0xFFF2F2F2),
          const Color(0xFFD6D2CC),
          const Color(0xFFBEB8AF),
        );
        canvas
          ..drawRect(
            Rect.fromLTWH(c.dx - 1, c.dy - 44, 2, 14),
            Paint()..color = const Color(0xFF555555),
          )
          ..drawRect(
            Rect.fromLTWH(c.dx, c.dy - 44 + sin(t * 3), 9, 6),
            Paint()..color = const Color(0xFFE4572E),
          );
      case Civic.school:
        _box(
          canvas,
          c,
          20,
          const Color(0xFFF5C9C0),
          const Color(0xFFE08E7E),
          const Color(0xFFC9705F),
        );
        canvas.drawCircle(
          c.translate(0, -26),
          4,
          Paint()..color = const Color(0xFFF2C94C),
        );
      case Civic.library:
        _box(
          canvas,
          c,
          22,
          const Color(0xFFE9E3F5),
          const Color(0xFFB9A8DE),
          const Color(0xFF9B86CF),
          windows: false,
        );
        for (var i = -2; i <= 2; i++) {
          canvas.drawRect(
            Rect.fromLTWH(c.dx + i * 5 - 1, c.dy - 19, 2, 14),
            Paint()..color = Colors.white,
          );
        }
      case Civic.observatory:
        _box(
          canvas,
          c,
          16,
          const Color(0xFFE3E6EA),
          const Color(0xFFAEB5BF),
          const Color(0xFF959DA8),
          windows: false,
        );
        canvas
          ..drawArc(
            Rect.fromCircle(center: c.translate(0, -18), radius: 11),
            pi,
            pi,
            true,
            Paint()..color = const Color(0xFFCDD3DA),
          )
          ..drawRect(
            Rect.fromLTWH(c.dx - 1, c.dy - 29, 3, 8),
            Paint()..color = const Color(0xFF39414D),
          );
      case Civic.university:
        _box(
          canvas,
          c,
          40,
          const Color(0xFFF0E6D8),
          const Color(0xFFCBB397),
          const Color(0xFFB39A7C),
        );
        canvas
          ..drawRect(
            Rect.fromLTWH(c.dx - 3, c.dy - 62, 6, 16),
            Paint()..color = const Color(0xFF8A6D4E),
          )
          ..drawPath(
            Path()
              ..moveTo(c.dx - 5, c.dy - 62)
              ..lineTo(c.dx, c.dy - 72)
              ..lineTo(c.dx + 5, c.dy - 62)
              ..close(),
            Paint()..color = const Color(0xFF8A6D4E),
          );
      case Civic.fountain:
        canvas
          ..drawOval(
            Rect.fromCenter(center: c, width: 26, height: 14),
            Paint()..color = const Color(0xFFCFC8BC),
          )
          ..drawOval(
            Rect.fromCenter(center: c.translate(0, -1), width: 18, height: 9),
            Paint()..color = const Color(0xFF6EC1E4),
          )
          ..drawRect(
            Rect.fromLTWH(c.dx - 1, c.dy - 8 + sin(t * 6) * 2, 2, 7),
            Paint()..color = Colors.white,
          );
    }
  }

  /// The open streets as straight runs a car or a person can travel:
  /// each row and column of road plots, two or more long. Built from the
  /// city, so a street the child lays joins the traffic the next frame.
  /// Worked out once per city: this painter is made again whenever the
  /// city changes, and only repainted, not remade, as time moves.
  late final List<List<(int, int)>> _laneCache = _lanes();

  List<List<(int, int)>> _lanes() {
    final lanes = <List<(int, int)>>[];
    bool road(int x, int y) => city.isOpen(x, y) && city.isRoad(x, y);
    for (final across in [true, false]) {
      for (var a = 0; a < City.size; a++) {
        var run = <(int, int)>[];
        for (var b = 0; b <= City.size; b++) {
          final (x, y) = across ? (b, a) : (a, b);
          if (b < City.size && road(x, y)) {
            run.add((x, y));
          } else {
            if (run.length >= 2) lanes.add(run);
            run = [];
          }
        }
      }
    }
    return lanes;
  }

  /// Where along [lane] something is at [phase] (0..1, there and back):
  /// on screen, and how far back (a plot's x + y) for drawing in order.
  (Offset, double) _along(List<(int, int)> lane, double phase, double side) {
    final there = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final pos = there * (lane.length - 1);
    final i = pos.floor().clamp(0, lane.length - 2);
    final f = pos - i;
    final (x0, y0) = lane[i];
    final (x1, y1) = lane[i + 1];
    final across = y0 == y1;
    // Keep to one side of the street, each way its own.
    final off = (phase < 0.5 ? side : -side) * 0.22;
    final px = x0 + (x1 - x0) * f + (across ? 0 : off);
    final py = y0 + (y1 - y0) * f + (across ? off : 0);
    return (geometry.at(px, py), px + py);
  }

  /// Cars, and a bus once the town has people to carry, on every open
  /// street: more homes, more traffic.
  void _traffic(Canvas canvas, void Function(double, void Function()) place) {
    final lanes = _laneCache;
    if (lanes.isEmpty) return;
    final homes = city.lots.where((l) => l.zone == Zone.home).length;
    final cars = min(2 + homes ~/ 3, 18);
    const colours = [
      Color(0xFFE4572E),
      Colors.white,
      Color(0xFF4A90D9),
      Color(0xFFF2C94C),
      Color(0xFF43AA8B),
      Color(0xFF7A5CFA),
    ];
    for (var i = 0; i < cars; i++) {
      final lane = lanes[(_hash(i, 7, 70) * lanes.length).floor()];
      final speed = 0.6 + _hash(i, 8, 71) * 0.6;
      final phase = (t * speed / (lane.length * 1.6) + _hash(i, 9, 72)) % 1;
      final (p, depth) = _along(lane, phase, 1);
      final bus = i == 0 && homes >= 6;
      final w = bus ? 13.0 : 7.0;
      // With pictures, a real car facing the way it goes.
      final across = lane[0].$2 == lane[1].$2;
      final heading = across
          ? (phase < 0.5 ? 'e' : 'w')
          : (phase < 0.5 ? 's' : 'n');
      const models = ['sedan', 'taxi', 'police', 'suv', 'delivery'];
      final car = _pictureOf(
        'car_${bus ? 'van' : models[i % models.length]}_$heading',
      );
      if (car != null) {
        place(depth, () {
          _sprite(canvas, p, car);
          if (night) {
            // Headlights on the way it faces.
            final ahead = switch (heading) {
              'e' => const Offset(5, 1.5),
              'w' => const Offset(-5, -1.5),
              's' => const Offset(-5, 1.5),
              _ => const Offset(5, -1.5),
            };
            final k = geometry.tileWidth / 52;
            canvas
              ..drawCircle(
                p + ahead * k + Offset(0, -3 * k),
                4 * k,
                Paint()..color = const Color(0x44FFF3B0),
              )
              ..drawCircle(
                p + ahead * k + Offset(0, -3 * k),
                1.3 * k,
                Paint()..color = const Color(0xFFFFF3B0),
              );
          }
        });
        continue;
      }
      place(depth, () {
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(p.dx - w / 2, p.dy - 5, w, bus ? 5 : 4),
              const Radius.circular(1.5),
            ),
            Paint()..color = bus ? const Color(0xFFF2B233) : colours[i % 6],
          )
          ..drawRect(
            Rect.fromLTWH(p.dx - w / 2 + 1, p.dy - 5, w - 2, 1.4),
            Paint()..color = const Color(0x5539414D),
          );
        if (night) {
          canvas.drawCircle(
            Offset(p.dx + (phase < 0.5 ? w / 2 : -w / 2), p.dy - 3),
            1.4,
            Paint()..color = const Color(0xFFFFF3B0),
          );
        }
      });
    }
  }

  /// People out walking, on the pavements: fewer after dark.
  void _people(Canvas canvas, void Function(double, void Function()) place) {
    final lanes = _laneCache;
    if (lanes.isEmpty) return;
    // Some of the people who live here are always out: more people, more
    // walking, up to what the pavements can take.
    final homes = city.lots.where((l) => l.zone == Zone.home).length;
    final out = population > 0 ? population ~/ 5 : homes;
    final walkers = min(out + 2, 30) ~/ (night ? 3 : 1);
    const clothes = [
      Color(0xFFD64545),
      Color(0xFF3F6E9E),
      Color(0xFF2E9D57),
      Color(0xFFF2B233),
      Color(0xFF8A5AB5),
      Color(0xFFEE7B30),
    ];
    for (var i = 0; i < walkers; i++) {
      final lane = lanes[(_hash(i, 3, 80) * lanes.length).floor()];
      final speed = 0.15 + _hash(i, 4, 81) * 0.12;
      final phase = (t * speed / lane.length + _hash(i, 5, 82)) % 1;
      final (p, depth) = _along(lane, phase, 1.9);
      final step = sin(t * 9 + i) * 0.6;
      place(
        depth,
        () => canvas
          ..drawRect(
            Rect.fromLTWH(p.dx - 0.9, p.dy - 5.5 + step.abs() * 0.3, 1.8, 3.6),
            Paint()..color = clothes[i % clothes.length],
          )
          ..drawCircle(
            Offset(p.dx, p.dy - 6.6),
            1.1,
            Paint()..color = const Color(0xFFF1C9A5),
          ),
      );
    }
  }

  /// The sky's traffic: birds by day, now and then a hot-air balloon,
  /// and a plane blinking over at night.
  void _air(Canvas canvas, Size size) {
    // Over the town, not the top of the map: the view opens zoomed on the
    // open districts, and the map's own sky is off the top of the screen.
    final r = city.radius.toDouble();
    const c = City.centre;
    final top = geometry.at(c - r, c - r).dy - 30;
    final left = geometry.at(c - r, c + r).dx - 40;
    final span = geometry.at(c + r, c - r).dx + 40 - left;
    if (!night) {
      final wing = Paint()
        ..color = const Color(0xFF39414D)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 4; i++) {
        final x = left + ((t * (10 + i * 3) + i * 70) % span);
        final y = top - 20 + i * 9 + sin(t * 0.8 + i) * 4;
        final flap = sin(t * 8 + i * 2) * 2;
        canvas.drawPath(
          Path()
            ..moveTo(x - 4, y - flap)
            ..lineTo(x, y)
            ..lineTo(x + 4, y - flap),
          wing,
        );
      }
      // A balloon for a minute out of every three.
      final drift = (t / 60) % 3;
      if (drift < 1) {
        final x = left + drift * span;
        final y = top - 10 + sin(t * 0.5) * 6;
        canvas
          ..drawCircle(
            Offset(x, y),
            9,
            Paint()..color = const Color(0xFFE4572E),
          )
          ..drawRect(
            Rect.fromLTWH(x - 9, y - 1.5, 18, 3),
            Paint()..color = const Color(0xFFF2C94C),
          )
          ..drawLine(
            Offset(x - 5, y + 7),
            Offset(x - 2, y + 14),
            Paint()..color = const Color(0xFF6B4A2B),
          )
          ..drawLine(
            Offset(x + 5, y + 7),
            Offset(x + 2, y + 14),
            Paint()..color = const Color(0xFF6B4A2B),
          )
          ..drawRect(
            Rect.fromLTWH(x - 3, y + 14, 6, 4),
            Paint()..color = const Color(0xFF8A6246),
          );
      }
      return;
    }
    final x = left + (t * 14) % span;
    final y = top - 25 + (x - left) * 0.05;
    if ((t * 2).floor().isEven) {
      canvas.drawCircle(
        Offset(x, y),
        1.6,
        Paint()..color = const Color(0xFFFF4D4D),
      );
    }
    canvas.drawCircle(Offset(x - 5, y), 1, Paint()..color = Colors.white70);
  }

  void _fireworks(Canvas canvas) {
    final (sx, sy) = City.civicPlots[Civic.fountain]!;
    final base = geometry.at(sx, sy);
    const colours = [
      Color(0xFFFF5A7A),
      Color(0xFFFFC93C),
      Color(0xFF5AD1FF),
      Color(0xFF8BE06A),
    ];
    for (var b = 0; b < 3; b++) {
      final p = (t / 1.4 + b * 0.33) % 1;
      final burst = Offset(base.dx + (b - 1) * 80, base.dy - 60 - b * 16);
      if (p < 0.25) {
        canvas.drawRect(
          Rect.fromLTWH(
            burst.dx - 1,
            base.dy - (p / 0.25) * (base.dy - burst.dy) - 2,
            2,
            5,
          ),
          Paint()..color = const Color(0xFFFFE08A),
        );
        continue;
      }
      final q = (p - 0.25) / 0.75;
      for (var s = 0; s < 22; s++) {
        final a = s / 22 * 2 * pi;
        canvas.drawCircle(
          burst + Offset(cos(a) * q * 50, sin(a) * q * 50 + q * q * 18),
          2.8,
          Paint()..color = colours[(s + b) % 4].withValues(alpha: 1 - q),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.city != city ||
      old.night != night ||
      old.festival != festival ||
      old.selected != selected ||
      old.sprites != sprites ||
      old.happening != happening ||
      old.population != population ||
      old.trouble?.day != trouble?.day ||
      old.trouble?.over != trouble?.over ||
      old.plan != plan;
}
