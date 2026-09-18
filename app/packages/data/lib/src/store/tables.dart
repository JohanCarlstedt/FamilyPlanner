import 'package:drift/drift.dart';

/// Synced content, decrypted (architecture doc §4 "Local store"). Disposable:
/// corruption is fixed by refetching, and a cache reset loses nothing.
@DataClassName('CachedObject')
class CachedObjects extends Table {
  TextColumn get id => text()();

  /// Backend ObjectKind.
  IntColumn get kind => integer()();
  TextColumn get scope => text()();
  IntColumn get version => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// As received, so an object this device can't read yet can be opened once
  /// its key arrives, without refetching.
  BlobColumn get envelope => blob().nullable()();

  /// Decrypted CBOR payload; null when deleted or not readable here.
  BlobColumn get payload => blob().nullable()();

  /// Why [payload] is null for a live object: `noAccess` or `damaged`.
  TextColumn get unreadable => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncStateEntry')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Unsynced user intent (architecture doc §4): precious. Ticked shopping items
/// and completed actions that haven't uploaded exist nowhere else. A separate
/// database file, never cleared by a cache reset.
@DataClassName('QueuedCommand')
class QueuedCommands extends Table {
  TextColumn get clientCommandId => text()();

  /// Order of intent, independent of clock changes.
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get targetId => text()();
  IntColumn get targetKind => integer()();
  TextColumn get scope => text()();
  BlobColumn get envelope => blob()();
  IntColumn get expectedVersion => integer().nullable()();
  DateTimeColumn get issuedAt => dateTime()();

  /// `pending`, or `conflict` / `rejected` for a person to resolve.
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
