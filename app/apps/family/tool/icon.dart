/// The app's icon, drawn rather than stored: every size is rendered from
/// this, so none of them drift apart.
///
/// Four bars in the member palette (Okabe–Ito, the same colours the app
/// gives people, chosen to survive colour blindness), at different heights.
/// It reads two ways on purpose: a week at a glance, and a family lined up
/// by height. Nothing in it is text, which is what keeps it legible at 48
/// pixels on a home screen.
library;

import 'dart:ui';

/// Material teal 900. The app themes from teal; this is the dark end of it,
/// so the member colours sit brightly on top.
const iconBackground = Color(0xFF004D40);

/// Okabe–Ito, as in MemberStyle.palette. Four of the six: more than that and
/// the bars get too thin to see at a launcher's size.
const _bars = <Color>[
  Color(0xFF0072B2), // blue
  Color(0xFFE69F00), // amber
  Color(0xFF009E73), // green
  Color(0xFFCC79A7), // pink
];

/// Tall, short, tallest, middling — uneven on purpose. Four equal bars read
/// as a chart; uneven ones read as people.
const _heights = <double>[0.46, 0.30, 0.56, 0.38];

/// Paints the icon into [size] pixels square.
///
/// [background] fills the square first — what iOS needs, since it masks the
/// corners itself and refuses transparency. Android's adaptive icon wants
/// the two layers apart, so the foreground is drawn alone.
///
/// [contentScale] shrinks the bars about the centre. Android's adaptive icon
/// crops to the middle two thirds, so a foreground drawn edge to edge loses
/// its outermost bars on a round launcher.
void paintIcon(
  Canvas canvas,
  double size, {
  bool background = true,
  double contentScale = 1,
}) {
  if (background) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = iconBackground,
    );
  }

  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.scale(contentScale);
  canvas.translate(-size / 2, -size / 2);

  const barWidth = 0.13;
  const gap = 0.055;
  // 0.80, not 0.76: it puts the same fifth of the square above the tallest
  // bar as below the feet, which is what stops it looking like it is
  // sliding off the bottom.
  const baseline = 0.80;
  final total = _bars.length * barWidth + (_bars.length - 1) * gap;
  var x = (1 - total) / 2;

  for (final (i, color) in _bars.indexed) {
    final height = _heights[i];
    final rect = Rect.fromLTWH(
      x * size,
      (baseline - height) * size,
      barWidth * size,
      height * size,
    );
    canvas.drawRRect(
      // A radius of half the width makes the ends semicircles: the top of a
      // bar, or a head, depending on how you look at it.
      RRect.fromRectAndRadius(rect, Radius.circular(barWidth * size / 2)),
      Paint()..color = color..isAntiAlias = true,
    );
    x += barWidth + gap;
  }

  canvas.restore();
}
