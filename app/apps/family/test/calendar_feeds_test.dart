import 'dart:io';

import 'package:family/src/integrations/calendar_feeds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final laget = File('../../packages/domain/test/fixtures/laget-sample.ics')
      .readAsBytesSync();

  CalendarFeeds answering(int status, List<int> body) =>
      CalendarFeeds(MockClient((_) async => http.Response.bytes(body, status)));

  test('a laget.se feed comes back as events', () async {
    final events = await answering(
      200,
      laget,
    ).download('https://cal.laget.se/LIF2003_F15.ics');
    expect(events, isNotEmpty);
    expect(events.first.uid, endsWith('@laget.se'));
  });

  test('a web page is not a calendar', () async {
    await expectLater(
      answering(200, '<html>Laget</html>'.codeUnits).download('https://x'),
      throwsFormatException,
    );
  });

  test('an error status says so', () async {
    await expectLater(
      answering(404, const []).download('https://x'),
      throwsA(isA<http.ClientException>()),
    );
  });
}
