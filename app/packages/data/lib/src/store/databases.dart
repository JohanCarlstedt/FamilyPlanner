import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'databases.g.dart';

@DriftDatabase(tables: [CachedObjects, SyncState, CachedBlobs])
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // 2: photos.
      if (from < 2) await m.createTable(cachedBlobs);
    },
  );
}

@DriftDatabase(
  tables: [QueuedCommands, DeviceState, ChatMessages, PendingBlobs],
)
class QueueDatabase extends _$QueueDatabase {
  QueueDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // 2: chat. Additive only; existing queued commands are untouched.
      if (from < 2) {
        await m.createTable(deviceState);
        await m.createTable(chatMessages);
      }
      // 3: photos waiting to upload.
      if (from < 3) await m.createTable(pendingBlobs);
    },
  );
}

/// Opens [file] encrypted with [key] (SQLite3 Multiple Ciphers, whose default
/// cipher is ChaCha20-Poly1305), and fails loudly on a wrong key rather than
/// letting the first query discover it.
QueryExecutor openEncrypted(File file, Uint8List key) {
  final hex = _hex(key);
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      db.execute("PRAGMA hexkey = '$hex';");
      // Touches the schema, which fails with "file is not a database" under a
      // wrong key.
      db.select('SELECT count(*) FROM sqlite_master;');
      db.execute('PRAGMA foreign_keys = ON;');
      // Two connections at once are normal: on Android a push starts a
      // second engine in the same process while the app's own still has the
      // files open. Readers and a writer then pass each other (WAL), and a
      // second writer waits its turn rather than failing "database is
      // locked" and dropping the notification it was about to show.
      db.execute('PRAGMA busy_timeout = 10000;');
      db.select('PRAGMA journal_mode = WAL;');
    },
  );
}

/// Whether [file] opens under [key]; a file not there yet does. False means
/// it was written under another key, by an identity this device no longer
/// has.
bool opensWith(File file, Uint8List key) {
  if (!file.existsSync()) return true;
  final db = sqlite3.open(file.path);
  try {
    db.execute("PRAGMA hexkey = '${_hex(key)}';");
    db.select('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db.close();
  }
}

/// The files SQLite keeps beside [file] in WAL mode: removed or moved
/// with it, or a new database of the same name would find a stranger's log.
List<File> companionsOf(File file) => [
  File('${file.path}-wal'),
  File('${file.path}-shm'),
];

String _hex(Uint8List key) {
  if (key.length != 32) throw ArgumentError('database keys are 32 bytes');
  return key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
