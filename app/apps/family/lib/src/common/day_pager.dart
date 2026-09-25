import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A bottom sheet of days side by side: swipe for the day before or
/// after, or tap the arrows beside the date, which also say that the
/// sheet swipes at all.
///
/// Days are `DateTime.utc` date fields, from [first] to [last].
Future<void> showDayPager(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  required DateTime initial,
  required String Function(String day) title,
  required Widget Function(BuildContext context, DateTime day) page,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DayPager(
    first: first,
    last: last,
    initial: initial,
    title: title,
    page: page,
  ),
);

class _DayPager extends StatefulWidget {
  const _DayPager({
    required this.first,
    required this.last,
    required this.initial,
    required this.title,
    required this.page,
  });

  final DateTime first;
  final DateTime last;
  final DateTime initial;
  final String Function(String day) title;
  final Widget Function(BuildContext context, DateTime day) page;

  @override
  State<_DayPager> createState() => _DayPagerState();
}

class _DayPagerState extends State<_DayPager> {
  late final int _count = widget.last.difference(widget.first).inDays + 1;
  late int _index = widget.initial
      .difference(widget.first)
      .inDays
      .clamp(0, _count - 1);
  late final _pages = PageController(initialPage: _index);

  DateTime _day(int i) =>
      DateTime.utc(widget.first.year, widget.first.month, widget.first.day + i);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final name = DateFormat('EEEE d MMMM', locale).format(_day(_index));
    // A page needs a height of its own to sit in; tall enough for a day,
    // never taller than most of the screen (a phone turned sideways).
    final height = (MediaQuery.sizeOf(context).height * 0.75).clamp(
      240.0,
      480.0,
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .previousPageTooltip,
                  onPressed: _index > 0 ? () => _go(_index - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    widget.title(name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: _index < _count - 1 ? () => _go(_index + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _pages,
              itemCount: _count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: widget.page(context, _day(i)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
