import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "What's new" is only right if it was written for this build: after a
/// version bump, run `python3 tool/whats_new.py`.
void main() {
  test("what's new is this build's, with its notes in both languages", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final build = int.parse(
      RegExp(r'^version:\s*\S+\+(\d+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!,
    );
    final data = jsonDecode(File('assets/whats_new.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(data['build'], build, reason: 'run python3 tool/whats_new.py');
    final notes = (data['notes'] as Map<String, dynamic>)['$build']
        as Map<String, dynamic>?;
    expect(notes, isNotNull, reason: 'release-notes/$build.json is missing');
    expect(notes!.keys, containsAll(['en-GB', 'sv']));
  });
}
