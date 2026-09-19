import 'package:domain/domain.dart';
import 'package:family/src/features/members/member_export.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const maja = Member(id: 'maja', displayName: 'Maja', role: MemberRole.child);

  EventPayload event(String title, List<String> going) => EventPayload.write(
    title: title,
    kind: EventKind.activity,
    localStart: DateTime.utc(2026, 9, 22, 17, 30),
    duration: const Duration(hours: 1),
    timeZone: 'Europe/Stockholm',
    participantIds: going,
  );

  test('only what concerns the member, in both files', () {
    final payloads = [
      ('a', event('Fotboll', ['maja'])),
      ('b', event('Parents\' dinner', ['anna'])),
    ];
    final export = MemberExport.build(
      member: maja,
      payloads: payloads,
      events: [for (final (id, e) in payloads) e.toDomain(id)!],
      messages: [
        ChatMessage(
          id: '1',
          group: 'family',
          sender: 'maja-tablet',
          sentAt: DateTime.utc(2026, 9, 20, 10),
          text: 'Hej!',
          mine: false,
        ),
        ChatMessage(
          id: '2',
          group: 'family',
          sender: 'anna-phone',
          sentAt: DateTime.utc(2026, 9, 20, 10, 1),
          text: 'Hej Maja',
          mine: true,
        ),
      ],
      deviceOwners: {'maja-tablet': 'maja', 'anna-phone': 'anna'},
      now: DateTime.utc(2026, 9, 21),
    );
    expect(
      [for (final e in export.data['events']! as List) (e as Map)['title']],
      ['Fotboll'],
    );
    expect(export.data['chatMessages'], [
      {'sentAt': '2026-09-20T10:00:00.000Z', 'text': 'Hej!'},
    ]);
    expect(
      ICalendar.parse(
        export.calendar,
        timeZone: 'Europe/Stockholm',
      ).map((e) => e.title),
      ['Fotboll'],
    );
  });
}
