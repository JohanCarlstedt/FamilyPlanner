import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../common/l10n.dart';
import '../../common/day_pager.dart';
import '../../integrations/electricity.dart';
import '../../data/family_repository.dart' show familyTimeZone;

String _two(int n) => n.toString().padLeft(2, '0');

/// A clock hour, as a bar is: "14–15".
String _hour(DateTime at) => '${_two(at.hour)}–${_two((at.hour + 1) % 24)}';

/// A whole hour from a quarter, as the cheapest and dearest are: they may
/// start at a quarter past, and "08–09" beside a bar that says otherwise
/// read as the numbers disagreeing. "08:15–09:15".
String _window(DateTime from) {
  final until = from.add(const Duration(hours: 1));
  return '${_two(from.hour)}:${_two(from.minute)}–'
      '${_two(until.hour)}:${_two(until.minute)}';
}

/// The day's average price beside the weather, when the family has
/// switched it on and the day's price is out. Tap it for the day hour by
/// hour.
class DayPriceBadge extends ConsumerWidget {
  const DayPriceBadge({super.key, required this.date});

  /// The day, as `DateTime.utc` date fields.
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(dayPriceProvider(date)).value;
    if (price == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDayPrice(context, date),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              context.l10n.electricityOre(price.averageOre.round()),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day hour by hour: a bar a clock hour, the cheapest and dearest
/// named in words as well as marked, and a bar tapped says its price.
/// Swipe for the day before or after: back a month, forward to tomorrow,
/// which is as far as prices are published.
Future<void> showDayPrice(BuildContext context, DateTime date) {
  final now = tz.TZDateTime.now(tz.getLocation(familyTimeZone));
  final today = DateTime.utc(now.year, now.month, now.day);
  return showDayPager(
    context,
    first: today.subtract(const Duration(days: 30)),
    last: today.add(const Duration(days: 1)),
    initial: date,
    title: context.l10n.electricityTitle,
    page: (_, day) => _DayPricePage(date: day),
  );
}

class _DayPricePage extends ConsumerStatefulWidget {
  const _DayPricePage({required this.date});

  final DateTime date;

  @override
  ConsumerState<_DayPricePage> createState() => _DayPricePageState();
}

class _DayPricePageState extends ConsumerState<_DayPricePage> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final found = ref.watch(dayPriceProvider(widget.date));
    final price = found.value;
    if (price == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: found.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Text(
                l10n.electricityNone,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
      );
    }
    final picked = _picked == null ? null : price.hours[_picked!];
    final now = DateTime.now();
    final nowHour = DateTime.utc(now.year, now.month, now.day, now.hour);

    // On a phone turned sideways the sheet has half the height: the chart
    // gives way and the rest scrolls, rather than running off the bottom.
    final chartHeight = (MediaQuery.sizeOf(context).height * 0.35).clamp(
      110.0,
      180.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.electricityAverage(price.averageOre.round()),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (d) {
                final i =
                    (d.localPosition.dx / box.maxWidth * price.hours.length)
                        .floor()
                        .clamp(0, price.hours.length - 1);
                setState(() => _picked = _picked == i ? null : i);
              },
              child: CustomPaint(
                size: Size(box.maxWidth, chartHeight),
                painter: _HourBars(
                  hours: price.hours,
                  cheapest: price.hours.indexWhere(
                    (h) => h.$1.hour == price.cheapestFrom.hour,
                  ),
                  dearest: price.hours.indexWhere(
                    (h) => h.$1.hour == price.dearestFrom.hour,
                  ),
                  picked: _picked,
                  now: price.hours.indexWhere((h) => h.$1 == nowHour),
                  bar: theme.colorScheme.primary,
                  low: const Color(0xFF2E9D57),
                  high: theme.colorScheme.error,
                  axis: theme.colorScheme.outlineVariant,
                  ink: theme.colorScheme.onSurfaceVariant,
                  surface: theme.colorScheme.surface,
                  textStyle: theme.textTheme.labelSmall!,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          picked == null
              ? l10n.electricityTapHint
              : l10n.electricityHour(_hour(picked.$1), picked.$2.round()),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _Line(
          icon: Icons.arrow_downward,
          colour: const Color(0xFF2E9D57),
          text: l10n.electricityCheapest(
            _window(price.cheapestFrom),
            price.cheapestOre.round(),
          ),
        ),
        _Line(
          icon: Icons.arrow_upward,
          colour: theme.colorScheme.error,
          text: l10n.electricityDearest(
            _window(price.dearestFrom),
            price.dearestOre.round(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.electricitySource,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.colour, required this.text});

  final IconData icon;
  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// One bar a clock hour, standing on a baseline, rounded at the top, a
/// small gap between; hour labels every sixth hour and the top of the
/// scale, all in ordinary text colour.
class _HourBars extends CustomPainter {
  _HourBars({
    required this.hours,
    required this.cheapest,
    required this.dearest,
    required this.picked,
    required this.now,
    required this.bar,
    required this.low,
    required this.high,
    required this.axis,
    required this.ink,
    required this.surface,
    required this.textStyle,
  });

  final List<(DateTime, double)> hours;
  final int cheapest;
  final int dearest;
  final int? picked;
  final int now;
  final Color bar;
  final Color low;
  final Color high;
  final Color axis;
  final Color ink;
  final Color surface;
  final TextStyle textStyle;

  static const _labels = 18.0;

  void _text(Canvas canvas, String s, Offset at, {bool centre = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: textStyle.copyWith(color: ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, centre ? at.translate(-p.width / 2, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;
    final top = hours.map((h) => h.$2).reduce((a, b) => a > b ? a : b);
    // Prices can go below zero; the baseline is zero or the lowest price.
    final bottom = hours
        .map((h) => h.$2)
        .reduce((a, b) => a < b ? a : b)
        .clamp(double.negativeInfinity, 0.0);
    final span = (top - bottom) <= 0 ? 1.0 : top - bottom;
    final chart = size.height - _labels;
    double y(double ore) => chart - (ore - bottom) / span * chart;
    final slot = size.width / hours.length;
    final width = (slot - 2).clamp(1.0, 24.0);

    // Baseline at zero, and the top of the scale named.
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    _text(canvas, '${top.round()}', const Offset(0, 0));

    for (var i = 0; i < hours.length; i++) {
      final (at, ore) = hours[i];
      final x = i * slot + (slot - width) / 2;
      final from = y(0), to = y(ore);
      final colour = i == cheapest
          ? low
          : i == dearest
          ? high
          : bar.withValues(alpha: picked == null || picked == i ? 0.85 : 0.35);
      final rect = Rect.fromLTRB(
        x,
        from < to ? from : to,
        x + width,
        from < to ? to : from,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: ore >= 0 ? const Radius.circular(4) : Radius.zero,
          topRight: ore >= 0 ? const Radius.circular(4) : Radius.zero,
          bottomLeft: ore < 0 ? const Radius.circular(4) : Radius.zero,
          bottomRight: ore < 0 ? const Radius.circular(4) : Radius.zero,
        ),
        Paint()..color = colour,
      );
      if (i == picked) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = ink,
        );
      }
      if (i == now) {
        canvas.drawCircle(
          Offset(x + width / 2, chart + 3),
          2.5,
          Paint()..color = ink,
        );
      }
      if (at.hour % 6 == 0) {
        _text(
          canvas,
          at.hour.toString().padLeft(2, '0'),
          Offset(x + width / 2, chart + 5),
          centre: true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HourBars old) =>
      old.picked != picked || old.hours != hours || old.now != now;
}
