import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../common/l10n.dart';
import 'today_providers.dart';

/// Android's home-screen widget (spec §11). The phone writes lines it has
/// already decrypted for the widget to draw: a widget process never holds a
/// key, and nothing of this leaves the device.
Future<void> updateTodayWidget(Ref ref) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final state = await ref.read(todayProvider.future);
    final l10n = lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale, appLocales),
    );
    final today = state.local(state.now);
    final time = DateFormat('HH:mm');
    final upcoming = [
      for (final entry in state.agenda.entries)
        if (entry.end.isAfter(state.now)) entry,
    ];
    final lines = [
      for (final entry in upcoming.take(4))
        '${time.format(state.local(entry.start))}  ${entry.event.title}',
    ];

    await HomeWidget.saveWidgetData(
      'widget.title',
      DateFormat('EEEE d MMMM', l10n.localeName).format(today),
    );
    await HomeWidget.saveWidgetData(
      'widget.body',
      lines.isEmpty ? l10n.kitchenNothingOn : lines.join('\n'),
    );
    await HomeWidget.updateWidget(name: 'TodayWidgetProvider');
  } catch (e) {
    // A widget that can't be drawn must never stop a sync.
    debugPrint('Home widget not updated: $e');
  }
}
