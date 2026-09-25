import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../common/day_pager.dart';
import '../../common/l10n.dart';
import 'week_screen.dart' show weatherIcon;

/// The day's weather hour by hour, from a tap on it in the week.
///
/// A strip of hours rather than a chart: temperature and rain are two
/// measures on two scales, and one chart with two axes is the classic way
/// to make both unreadable. A column an hour — time, sky, temperature,
/// rain when there is any, wind — scrolled sideways, as a weather app is.
///
/// Swipe for the day before or after, as far as the forecast reaches.
/// Swiping on the hours scrolls the hours; anywhere else, or the arrows
/// beside the date, changes the day.
Future<void> showDayWeather(
  BuildContext context,
  Map<DateTime, DayWeather> days,
  DateTime initial,
) {
  final dates = days.keys.toList()..sort();
  return showDayPager(
    context,
    first: dates.first,
    last: dates.last,
    initial: initial,
    title: context.l10n.weatherTitle,
    page: (context, date) => switch (days[date]) {
      final day? when day.hours.isNotEmpty => _DayWeatherPage(day: day),
      _ => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(context.l10n.weatherNone, textAlign: TextAlign.center),
      ),
    },
  );
}

class _DayWeatherPage extends StatelessWidget {
  const _DayWeatherPage({required this.day});

  final DayWeather day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final nowHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final sixHourly =
        day.hours.isNotEmpty && day.hours.first.step > const Duration(hours: 1);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(weatherIcon(day.symbol), size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.weatherDegrees(day.high.round(), day.low.round()),
              style: theme.textTheme.bodyLarge,
            ),
            if (day.millimetres >= 0.5) ...[
              const SizedBox(width: 12),
              Text(
                l10n.weatherMillimetres(day.millimetres.round()),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: day.hours.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final h = day.hours[i];
              final isNow =
                  !h.at.isAfter(nowHour) && h.at.add(h.step).isAfter(nowHour);
              return Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isNow
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      h.at.hour.toString().padLeft(2, '0'),
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Icon(weatherIcon(h.symbol), size: 24),
                    const SizedBox(height: 6),
                    Text(
                      l10n.weatherTemp(h.temperature.round()),
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    // Rain only where there is some: a column of
                    // "0 mm" is noise that hides the hour that isn't.
                    if (h.millimetres >= 0.1)
                      Text(
                        '${h.millimetres.toStringAsFixed(1)} mm',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    if (h.windSpeed case final wind?)
                      Text(l10n.weatherWind(wind.round()), style: muted),
                  ],
                ),
              );
            },
          ),
        ),
        if (sixHourly) ...[
          const SizedBox(height: 8),
          Text(l10n.weatherSixHours, style: muted),
        ],
        const SizedBox(height: 12),
        Text(l10n.weatherSource, style: muted),
      ],
    );
  }
}
