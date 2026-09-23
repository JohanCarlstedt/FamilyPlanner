import 'package:family/l10n/generated/app_localizations.dart';
import 'package:family/src/reminders/request_announcer.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A new poll's notification, under its question.
///
/// Reported from a real lock screen: "Ny omröstning: Ska jag cykla till
/// skolan?" with, underneath, "Kryssa i alla middagar du gärna äter". The
/// line was written when polls were only ever about dinner.
void main() {
  setUpAll(tzdata.initializeTimeZones);
  final sv = lookupAppLocalizations(const Locale('sv'));

  MealPollPayload poll(PollTopic topic) => MealPollPayload.write(
    title: 'Ska jag cykla till skolan?',
    topic: topic,
    // 18:00 in Stockholm on Friday 25 September.
    closesAt: DateTime.utc(2026, 9, 25, 16),
    options: const [],
    eligible: const ['anna'],
    createdBy: 'maja',
  );

  test('a question about anything says when to answer by', () {
    final body = RequestAnnouncer.pollOpenedBody(sv, poll(PollTopic.anything));
    expect(body, isNot(contains('middag')));
    expect(body, startsWith('Svara senast'));
    // In the family's zone, not UTC: 18:00, not 16:00.
    expect(body, contains('18:00'));
  });

  test('a dinner poll still asks about dinner', () {
    expect(
      RequestAnnouncer.pollOpenedBody(sv, poll(PollTopic.meal)),
      'Kryssa i alla middagar du gärna äter',
    );
  });
}
