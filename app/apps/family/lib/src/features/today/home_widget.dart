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
/// iOS reaches the widget through an app group; Android through the
/// package's own shared preferences.
const _appGroup = 'group.io.github.johancarlstedt.family';

/// Named in full: the dev flavour's application id carries a `.dev`
/// suffix, but the provider class stays in the base package.
const _androidProvider = 'io.github.johancarlstedt.family.TodayWidgetProvider';

/// What the widget was last given, so a sync that changed nothing
/// doesn't redraw it.
(String, String)? _lastDrawn;

Future<void> updateTodayWidget(Ref ref) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  try {
    if (Platform.isIOS) await HomeWidget.setAppGroupId(_appGroup);
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

    final title = DateFormat('EEEE d MMMM', l10n.localeName).format(today);
    final body = lines.isEmpty ? l10n.kitchenNothingOn : lines.join('\n');
    if (_lastDrawn == (title, body)) return;

    await HomeWidget.saveWidgetData('widget.title', title);
    await HomeWidget.saveWidgetData('widget.body', body);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: _androidProvider,
      iOSName: 'TodayWidget',
    );
    _lastDrawn = (title, body);
  } catch (e) {
    // A widget that can't be drawn must never stop a sync.
    debugPrint('Home widget not updated: $e');
  }
}
