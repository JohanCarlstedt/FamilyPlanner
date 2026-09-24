import 'dart:math';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  });

  final City city;

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
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
          ),
        ),
      );
    },
  );
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
  }) : super(repaint: time);

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
    // Back to front, so nearer buildings stand in front of further ones.
    for (var s = 0; s < City.size * 2; s++) {
      for (var x = 0; x < City.size; x++) {
        final y = s - x;
        if (y < 0 || y >= City.size) continue;
        _plot(canvas, x, y);
      }
    }
    _cars(canvas);
    if (festival) _fireworks(canvas);
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
    canvas.drawPath(
      ground,
      Paint()
        ..color = road
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
    if (road) {
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 2, height: 2),
        Paint()
          ..color = night ? const Color(0xFF6B6F79) : const Color(0xFFC9CBD0),
      );
    }
    if (selected == (x, y)) {
      canvas.drawPath(
        ground,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFE066),
      );
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
    if (pine) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 6 * scale, c.dy - 8 * scale)
          ..lineTo(c.dx, c.dy - 24 * scale)
          ..lineTo(c.dx + 6 * scale, c.dy - 8 * scale)
          ..close(),
        leaf,
      );
    } else {
      canvas.drawCircle(c.translate(0, -15 * scale), 7 * scale, leaf);
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

  void _cars(Canvas canvas) {
    final homes = city.lots.where((l) => l.zone == Zone.home).length;
    final cars = min(2 + homes ~/ 5, 12);
    final span = city.radius * 2 + 1;
    const colours = [
      Color(0xFFE4572E),
      Colors.white,
      Color(0xFF4A90D9),
      Color(0xFFF2C94C),
    ];
    for (var i = 0; i < cars; i++) {
      final along = ((t / 9 + i * 1.37) % 1) * span - city.radius;
      final across = i.isEven;
      final p = across
          ? geometry.at(City.centre + along, City.centre)
          : geometry.at(City.centre, City.centre + along);
      canvas.drawRect(
        Rect.fromLTWH(p.dx - 4, p.dy - 5, 8, 4),
        Paint()..color = colours[i % 4],
      );
      if (night) {
        canvas.drawRect(
          Rect.fromLTWH(p.dx + 3, p.dy - 4, 2, 2),
          Paint()..color = const Color(0xFFFFF3B0),
        );
      }
    }
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
      old.selected != selected;
}
