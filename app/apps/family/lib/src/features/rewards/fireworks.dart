import 'dart:math';

import 'package:flutter/material.dart';

/// A short burst of fireworks over whatever is on screen.
///
/// For a child who has just finished their homework: the moment itself,
/// not a number. It never blocks a tap, is gone in under two seconds, and
/// is skipped entirely when the phone has been asked to reduce motion.
void showFireworks(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Fireworks(onDone: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
}

class Fireworks extends StatefulWidget {
  const Fireworks({super.key, required this.onDone, this.seed});

  final VoidCallback onDone;

  /// Fixed in tests so a picture of it is the same picture every time.
  final int? seed;

  static const duration = Duration(milliseconds: 1800);

  @override
  State<Fireworks> createState() => _FireworksState();
}

class _Burst {
  _Burst(this.origin, this.start, this.sparks);

  /// Where it goes off, as a fraction of the screen.
  final Offset origin;

  /// When it goes off, as a fraction of the whole show.
  final double start;
  final List<(Offset, Color)> sparks;
}

class _FireworksState extends State<Fireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Fireworks.duration,
  )..forward().whenComplete(widget.onDone);

  late final List<_Burst> _bursts = () {
    final random = Random(widget.seed);
    const colours = [
      Color(0xFFFFC107),
      Color(0xFFE91E63),
      Color(0xFF03A9F4),
      Color(0xFF8BC34A),
      Color(0xFFFF5722),
      Color(0xFF9C27B0),
    ];
    return [
      for (final (i, start) in const [0.0, 0.18, 0.34].indexed)
        _Burst(
          Offset(0.2 + 0.6 * random.nextDouble(), 0.15 + 0.35 * random.nextDouble()),
          start,
          [
            for (var s = 0; s < 32; s++)
              (
                Offset.fromDirection(
                  2 * pi * s / 32 + random.nextDouble() * 0.2,
                  0.5 + 0.5 * random.nextDouble(),
                ),
                colours[(i * 2 + s) % colours.length],
              ),
          ],
        ),
    ];
  }();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (_, _) => CustomPaint(
      size: Size.infinite,
      painter: _Painter(_bursts, _clock.value),
    ),
  );
}

class _Painter extends CustomPainter {
  _Painter(this.bursts, this.t);

  final List<_Burst> bursts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final reach = size.shortestSide * 0.32;
    for (final b in bursts) {
      final local = ((t - b.start) / (1 - b.start)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final centre = Offset(b.origin.dx * size.width, b.origin.dy * size.height);
      // Out fast, then slowing, then falling a little as it fades.
      final out = Curves.easeOutCubic.transform(local);
      final fall = Offset(0, local * local * reach * 0.35);
      final paint = Paint()..style = PaintingStyle.fill;
      for (final (direction, colour) in b.sparks) {
        paint.color = colour.withValues(alpha: 1 - local);
        canvas.drawCircle(
          centre + direction * (out * reach) + fall,
          3.2 * (1 - local * 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.t != t;
}
