import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'databases.g.dart';

@DriftDatabase(tables: [CachedObjects, SyncState])
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

@DriftDatabase(tables: [QueuedCommands])
class QueueDatabase extends _$QueueDatabase {
  QueueDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

/// Opens [file] encrypted with [key] (SQLite3 Multiple Ciphers, whose default
/// cipher is ChaCha20-Poly1305), and fails loudly on a wrong key rather than
/// letting the first query discover it.
QueryExecutor openEncrypted(File file, Uint8List key) {
  if (key.length != 32) throw ArgumentError('database keys are 32 bytes');
  final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      db.execute("PRAGMA hexkey = '$hex';");
      // Touches the schema, which fails with "file is not a database" under a
      // wrong key.
      db.select('SELECT count(*) FROM sqlite_master;');
      db.execute('PRAGMA foreign_keys = ON;');
    },
  );
}
