import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() => dir = Directory.systemTemp.createTempSync('databases'));
  tearDown(() => dir.deleteSync(recursive: true));

  // On Android a push starts a second engine in the app's own process, which
  // opens the same files while the app still has them open.
  test('a second connection waits for the first rather than failing', () async {
    final file = File('${dir.path}/queue.db');
    final app = QueueDatabase(openEncrypted(file, key));
    final wake = QueueDatabase(openEncrypted(file, key));
    addTearDown(app.close);
    addTearDown(wake.close);

    ChatMessagesCompanion message(String id) => ChatMessagesCompanion.insert(
      id: id,
      groupId: 'g',
      sender: 'd',
      sentAt: DateTime.utc(2026),
      payload: Uint8List(0),
    );

    await app.into(app.chatMessages).insert(message('0'));
    final writing = app.transaction(() async {
      await app.into(app.chatMessages).insert(message('1'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Read mid-transaction, then write once it lets go.
    expect(await wake.select(wake.chatMessages).get(), hasLength(1));
    await wake.into(wake.chatMessages).insert(message('2'));
    await writing;

    expect(await app.select(app.chatMessages).get(), hasLength(3));
    expect(File('${file.path}-wal').existsSync(), isTrue);
  });
}
