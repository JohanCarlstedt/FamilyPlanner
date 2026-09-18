// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'databases.dart';

// ignore_for_file: type=lint
class $CachedObjectsTable extends CachedObjects
    with TableInfo<$CachedObjectsTable, CachedObject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedObjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<Uint8List> envelope = GeneratedColumn<Uint8List>(
    'envelope',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadableMeta = const VerificationMeta(
    'unreadable',
  );
  @override
  late final GeneratedColumn<String> unreadable = GeneratedColumn<String>(
    'unreadable',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    scope,
    version,
    deleted,
    envelope,
    payload,
    unreadable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_objects';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedObject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('unreadable')) {
      context.handle(
        _unreadableMeta,
        unreadable.isAcceptableOrUnknown(data['unreadable']!, _unreadableMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedObject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedObject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      ),
      unreadable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unreadable'],
      ),
    );
  }

  @override
  $CachedObjectsTable createAlias(String alias) {
    return $CachedObjectsTable(attachedDatabase, alias);
  }
}

class CachedObject extends DataClass implements Insertable<CachedObject> {
  final String id;

  /// Backend ObjectKind.
  final int kind;
  final String scope;
  final int version;
  final bool deleted;

  /// As received, so an object this device can't read yet can be opened once
  /// its key arrives, without refetching.
  final Uint8List? envelope;

  /// Decrypted CBOR payload; null when deleted or not readable here.
  final Uint8List? payload;

  /// Why [payload] is null for a live object: `noAccess` or `damaged`.
  final String? unreadable;
  const CachedObject({
    required this.id,
    required this.kind,
    required this.scope,
    required this.version,
    required this.deleted,
    this.envelope,
    this.payload,
    this.unreadable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    map['scope'] = Variable<String>(scope);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || envelope != null) {
      map['envelope'] = Variable<Uint8List>(envelope);
    }
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<Uint8List>(payload);
    }
    if (!nullToAbsent || unreadable != null) {
      map['unreadable'] = Variable<String>(unreadable);
    }
    return map;
  }

  CachedObjectsCompanion toCompanion(bool nullToAbsent) {
    return CachedObjectsCompanion(
      id: Value(id),
      kind: Value(kind),
      scope: Value(scope),
      version: Value(version),
      deleted: Value(deleted),
      envelope: envelope == null && nullToAbsent
          ? const Value.absent()
          : Value(envelope),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      unreadable: unreadable == null && nullToAbsent
          ? const Value.absent()
          : Value(unreadable),
    );
  }

  factory CachedObject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedObject(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      scope: serializer.fromJson<String>(json['scope']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      envelope: serializer.fromJson<Uint8List?>(json['envelope']),
      payload: serializer.fromJson<Uint8List?>(json['payload']),
      unreadable: serializer.fromJson<String?>(json['unreadable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'scope': serializer.toJson<String>(scope),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
      'envelope': serializer.toJson<Uint8List?>(envelope),
      'payload': serializer.toJson<Uint8List?>(payload),
      'unreadable': serializer.toJson<String?>(unreadable),
    };
  }

  CachedObject copyWith({
    String? id,
    int? kind,
    String? scope,
    int? version,
    bool? deleted,
    Value<Uint8List?> envelope = const Value.absent(),
    Value<Uint8List?> payload = const Value.absent(),
    Value<String?> unreadable = const Value.absent(),
  }) => CachedObject(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    scope: scope ?? this.scope,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
    envelope: envelope.present ? envelope.value : this.envelope,
    payload: payload.present ? payload.value : this.payload,
    unreadable: unreadable.present ? unreadable.value : this.unreadable,
  );
  CachedObject copyWithCompanion(CachedObjectsCompanion data) {
    return CachedObject(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      scope: data.scope.present ? data.scope.value : this.scope,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
      payload: data.payload.present ? data.payload.value : this.payload,
      unreadable: data.unreadable.present
          ? data.unreadable.value
          : this.unreadable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedObject(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('envelope: $envelope, ')
          ..write('payload: $payload, ')
          ..write('unreadable: $unreadable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    scope,
    version,
    deleted,
    $driftBlobEquality.hash(envelope),
    $driftBlobEquality.hash(payload),
    unreadable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedObject &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.scope == this.scope &&
          other.version == this.version &&
          other.deleted == this.deleted &&
          $driftBlobEquality.equals(other.envelope, this.envelope) &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.unreadable == this.unreadable);
}

class CachedObjectsCompanion extends UpdateCompanion<CachedObject> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String> scope;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<Uint8List?> envelope;
  final Value<Uint8List?> payload;
  final Value<String?> unreadable;
  final Value<int> rowid;
  const CachedObjectsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.scope = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.envelope = const Value.absent(),
    this.payload = const Value.absent(),
    this.unreadable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedObjectsCompanion.insert({
    required String id,
    required int kind,
    required String scope,
    required int version,
    this.deleted = const Value.absent(),
    this.envelope = const Value.absent(),
    this.payload = const Value.absent(),
    this.unreadable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       scope = Value(scope),
       version = Value(version);
  static Insertable<CachedObject> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? scope,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<Uint8List>? envelope,
    Expression<Uint8List>? payload,
    Expression<String>? unreadable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (scope != null) 'scope': scope,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (envelope != null) 'envelope': envelope,
      if (payload != null) 'payload': payload,
      if (unreadable != null) 'unreadable': unreadable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedObjectsCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String>? scope,
    Value<int>? version,
    Value<bool>? deleted,
    Value<Uint8List?>? envelope,
    Value<Uint8List?>? payload,
    Value<String?>? unreadable,
    Value<int>? rowid,
  }) {
    return CachedObjectsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      envelope: envelope ?? this.envelope,
      payload: payload ?? this.payload,
      unreadable: unreadable ?? this.unreadable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (unreadable.present) {
      map['unreadable'] = Variable<String>(unreadable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedObjectsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('envelope: $envelope, ')
          ..write('payload: $payload, ')
          ..write('unreadable: $unreadable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateEntry extends DataClass implements Insertable<SyncStateEntry> {
  final String key;
  final String value;
  const SyncStateEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateEntry copyWith({String? key, String? value}) =>
      SyncStateEntry(key: key ?? this.key, value: value ?? this.value);
  SyncStateEntry copyWithCompanion(SyncStateCompanion data) {
    return SyncStateEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CacheDatabase extends GeneratedDatabase {
  _$CacheDatabase(QueryExecutor e) : super(e);
  $CacheDatabaseManager get managers => $CacheDatabaseManager(this);
  late final $CachedObjectsTable cachedObjects = $CachedObjectsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedObjects,
    syncState,
  ];
}

typedef $$CachedObjectsTableCreateCompanionBuilder =
    CachedObjectsCompanion Function({
      required String id,
      required int kind,
      required String scope,
      required int version,
      Value<bool> deleted,
      Value<Uint8List?> envelope,
      Value<Uint8List?> payload,
      Value<String?> unreadable,
      Value<int> rowid,
    });
typedef $$CachedObjectsTableUpdateCompanionBuilder =
    CachedObjectsCompanion Function({
      Value<String> id,
      Value<int> kind,
      Value<String> scope,
      Value<int> version,
      Value<bool> deleted,
      Value<Uint8List?> envelope,
      Value<Uint8List?> payload,
      Value<String?> unreadable,
      Value<int> rowid,
    });

class $$CachedObjectsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedObjectsTable> {
  $$CachedObjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unreadable => $composableBuilder(
    column: $table.unreadable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedObjectsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedObjectsTable> {
  $$CachedObjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unreadable => $composableBuilder(
    column: $table.unreadable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedObjectsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedObjectsTable> {
  $$CachedObjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get unreadable => $composableBuilder(
    column: $table.unreadable,
    builder: (column) => column,
  );
}

class $$CachedObjectsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedObjectsTable,
          CachedObject,
          $$CachedObjectsTableFilterComposer,
          $$CachedObjectsTableOrderingComposer,
          $$CachedObjectsTableAnnotationComposer,
          $$CachedObjectsTableCreateCompanionBuilder,
          $$CachedObjectsTableUpdateCompanionBuilder,
          (
            CachedObject,
            BaseReferences<_$CacheDatabase, $CachedObjectsTable, CachedObject>,
          ),
          CachedObject,
          PrefetchHooks Function()
        > {
  $$CachedObjectsTableTableManager(
    _$CacheDatabase db,
    $CachedObjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedObjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedObjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedObjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<Uint8List?> envelope = const Value.absent(),
                Value<Uint8List?> payload = const Value.absent(),
                Value<String?> unreadable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedObjectsCompanion(
                id: id,
                kind: kind,
                scope: scope,
                version: version,
                deleted: deleted,
                envelope: envelope,
                payload: payload,
                unreadable: unreadable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                required String scope,
                required int version,
                Value<bool> deleted = const Value.absent(),
                Value<Uint8List?> envelope = const Value.absent(),
                Value<Uint8List?> payload = const Value.absent(),
                Value<String?> unreadable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedObjectsCompanion.insert(
                id: id,
                kind: kind,
                scope: scope,
                version: version,
                deleted: deleted,
                envelope: envelope,
                payload: payload,
                unreadable: unreadable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedObjectsTable, CachedObject>(table),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedObjectsTable,
                    CachedObject
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedObjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedObjectsTable,
      CachedObject,
      $$CachedObjectsTableFilterComposer,
      $$CachedObjectsTableOrderingComposer,
      $$CachedObjectsTableAnnotationComposer,
      $$CachedObjectsTableCreateCompanionBuilder,
      $$CachedObjectsTableUpdateCompanionBuilder,
      (
        CachedObject,
        BaseReferences<_$CacheDatabase, $CachedObjectsTable, CachedObject>,
      ),
      CachedObject,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$CacheDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$CacheDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$CacheDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $SyncStateTable,
          SyncStateEntry,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateEntry,
            BaseReferences<_$CacheDatabase, $SyncStateTable, SyncStateEntry>,
          ),
          SyncStateEntry,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$CacheDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateEntry>(table),
                  BaseReferences<
                    _$CacheDatabase,
                    $SyncStateTable,
                    SyncStateEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $SyncStateTable,
      SyncStateEntry,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateEntry,
        BaseReferences<_$CacheDatabase, $SyncStateTable, SyncStateEntry>,
      ),
      SyncStateEntry,
      PrefetchHooks Function()
    >;

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$CachedObjectsTableTableManager get cachedObjects =>
      $$CachedObjectsTableTableManager(_db, _db.cachedObjects);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}

class $QueuedCommandsTable extends QueuedCommands
    with TableInfo<$QueuedCommandsTable, QueuedCommand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientCommandIdMeta = const VerificationMeta(
    'clientCommandId',
  );
  @override
  late final GeneratedColumn<String> clientCommandId = GeneratedColumn<String>(
    'client_command_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKindMeta = const VerificationMeta(
    'targetKind',
  );
  @override
  late final GeneratedColumn<int> targetKind = GeneratedColumn<int>(
    'target_kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeMeta = const VerificationMeta(
    'envelope',
  );
  @override
  late final GeneratedColumn<Uint8List> envelope = GeneratedColumn<Uint8List>(
    'envelope',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _issuedAtMeta = const VerificationMeta(
    'issuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> issuedAt = GeneratedColumn<DateTime>(
    'issued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientCommandId,
    seq,
    type,
    targetId,
    targetKind,
    scope,
    envelope,
    expectedVersion,
    issuedAt,
    state,
    lastError,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedCommand> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_command_id')) {
      context.handle(
        _clientCommandIdMeta,
        clientCommandId.isAcceptableOrUnknown(
          data['client_command_id']!,
          _clientCommandIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientCommandIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('target_kind')) {
      context.handle(
        _targetKindMeta,
        targetKind.isAcceptableOrUnknown(data['target_kind']!, _targetKindMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKindMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeMeta);
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    }
    if (data.containsKey('issued_at')) {
      context.handle(
        _issuedAtMeta,
        issuedAt.isAcceptableOrUnknown(data['issued_at']!, _issuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_issuedAtMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  QueuedCommand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedCommand(
      clientCommandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_command_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      targetKind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_kind'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      ),
      issuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}issued_at'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $QueuedCommandsTable createAlias(String alias) {
    return $QueuedCommandsTable(attachedDatabase, alias);
  }
}

class QueuedCommand extends DataClass implements Insertable<QueuedCommand> {
  final String clientCommandId;

  /// Order of intent, independent of clock changes.
  final int seq;
  final String type;
  final String targetId;
  final int targetKind;
  final String scope;
  final Uint8List envelope;
  final int? expectedVersion;
  final DateTime issuedAt;

  /// `pending`, or `conflict` / `rejected` for a person to resolve.
  final String state;
  final String? lastError;
  final int attempts;
  const QueuedCommand({
    required this.clientCommandId,
    required this.seq,
    required this.type,
    required this.targetId,
    required this.targetKind,
    required this.scope,
    required this.envelope,
    this.expectedVersion,
    required this.issuedAt,
    required this.state,
    this.lastError,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_command_id'] = Variable<String>(clientCommandId);
    map['seq'] = Variable<int>(seq);
    map['type'] = Variable<String>(type);
    map['target_id'] = Variable<String>(targetId);
    map['target_kind'] = Variable<int>(targetKind);
    map['scope'] = Variable<String>(scope);
    map['envelope'] = Variable<Uint8List>(envelope);
    if (!nullToAbsent || expectedVersion != null) {
      map['expected_version'] = Variable<int>(expectedVersion);
    }
    map['issued_at'] = Variable<DateTime>(issuedAt);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  QueuedCommandsCompanion toCompanion(bool nullToAbsent) {
    return QueuedCommandsCompanion(
      clientCommandId: Value(clientCommandId),
      seq: Value(seq),
      type: Value(type),
      targetId: Value(targetId),
      targetKind: Value(targetKind),
      scope: Value(scope),
      envelope: Value(envelope),
      expectedVersion: expectedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedVersion),
      issuedAt: Value(issuedAt),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      attempts: Value(attempts),
    );
  }

  factory QueuedCommand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedCommand(
      clientCommandId: serializer.fromJson<String>(json['clientCommandId']),
      seq: serializer.fromJson<int>(json['seq']),
      type: serializer.fromJson<String>(json['type']),
      targetId: serializer.fromJson<String>(json['targetId']),
      targetKind: serializer.fromJson<int>(json['targetKind']),
      scope: serializer.fromJson<String>(json['scope']),
      envelope: serializer.fromJson<Uint8List>(json['envelope']),
      expectedVersion: serializer.fromJson<int?>(json['expectedVersion']),
      issuedAt: serializer.fromJson<DateTime>(json['issuedAt']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientCommandId': serializer.toJson<String>(clientCommandId),
      'seq': serializer.toJson<int>(seq),
      'type': serializer.toJson<String>(type),
      'targetId': serializer.toJson<String>(targetId),
      'targetKind': serializer.toJson<int>(targetKind),
      'scope': serializer.toJson<String>(scope),
      'envelope': serializer.toJson<Uint8List>(envelope),
      'expectedVersion': serializer.toJson<int?>(expectedVersion),
      'issuedAt': serializer.toJson<DateTime>(issuedAt),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  QueuedCommand copyWith({
    String? clientCommandId,
    int? seq,
    String? type,
    String? targetId,
    int? targetKind,
    String? scope,
    Uint8List? envelope,
    Value<int?> expectedVersion = const Value.absent(),
    DateTime? issuedAt,
    String? state,
    Value<String?> lastError = const Value.absent(),
    int? attempts,
  }) => QueuedCommand(
    clientCommandId: clientCommandId ?? this.clientCommandId,
    seq: seq ?? this.seq,
    type: type ?? this.type,
    targetId: targetId ?? this.targetId,
    targetKind: targetKind ?? this.targetKind,
    scope: scope ?? this.scope,
    envelope: envelope ?? this.envelope,
    expectedVersion: expectedVersion.present
        ? expectedVersion.value
        : this.expectedVersion,
    issuedAt: issuedAt ?? this.issuedAt,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    attempts: attempts ?? this.attempts,
  );
  QueuedCommand copyWithCompanion(QueuedCommandsCompanion data) {
    return QueuedCommand(
      clientCommandId: data.clientCommandId.present
          ? data.clientCommandId.value
          : this.clientCommandId,
      seq: data.seq.present ? data.seq.value : this.seq,
      type: data.type.present ? data.type.value : this.type,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      targetKind: data.targetKind.present
          ? data.targetKind.value
          : this.targetKind,
      scope: data.scope.present ? data.scope.value : this.scope,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      issuedAt: data.issuedAt.present ? data.issuedAt.value : this.issuedAt,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedCommand(')
          ..write('clientCommandId: $clientCommandId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('scope: $scope, ')
          ..write('envelope: $envelope, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientCommandId,
    seq,
    type,
    targetId,
    targetKind,
    scope,
    $driftBlobEquality.hash(envelope),
    expectedVersion,
    issuedAt,
    state,
    lastError,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedCommand &&
          other.clientCommandId == this.clientCommandId &&
          other.seq == this.seq &&
          other.type == this.type &&
          other.targetId == this.targetId &&
          other.targetKind == this.targetKind &&
          other.scope == this.scope &&
          $driftBlobEquality.equals(other.envelope, this.envelope) &&
          other.expectedVersion == this.expectedVersion &&
          other.issuedAt == this.issuedAt &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.attempts == this.attempts);
}

class QueuedCommandsCompanion extends UpdateCompanion<QueuedCommand> {
  final Value<String> clientCommandId;
  final Value<int> seq;
  final Value<String> type;
  final Value<String> targetId;
  final Value<int> targetKind;
  final Value<String> scope;
  final Value<Uint8List> envelope;
  final Value<int?> expectedVersion;
  final Value<DateTime> issuedAt;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<int> attempts;
  const QueuedCommandsCompanion({
    this.clientCommandId = const Value.absent(),
    this.seq = const Value.absent(),
    this.type = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetKind = const Value.absent(),
    this.scope = const Value.absent(),
    this.envelope = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.issuedAt = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  QueuedCommandsCompanion.insert({
    required String clientCommandId,
    this.seq = const Value.absent(),
    required String type,
    required String targetId,
    required int targetKind,
    required String scope,
    required Uint8List envelope,
    this.expectedVersion = const Value.absent(),
    required DateTime issuedAt,
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.attempts = const Value.absent(),
  }) : clientCommandId = Value(clientCommandId),
       type = Value(type),
       targetId = Value(targetId),
       targetKind = Value(targetKind),
       scope = Value(scope),
       envelope = Value(envelope),
       issuedAt = Value(issuedAt);
  static Insertable<QueuedCommand> custom({
    Expression<String>? clientCommandId,
    Expression<int>? seq,
    Expression<String>? type,
    Expression<String>? targetId,
    Expression<int>? targetKind,
    Expression<String>? scope,
    Expression<Uint8List>? envelope,
    Expression<int>? expectedVersion,
    Expression<DateTime>? issuedAt,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (clientCommandId != null) 'client_command_id': clientCommandId,
      if (seq != null) 'seq': seq,
      if (type != null) 'type': type,
      if (targetId != null) 'target_id': targetId,
      if (targetKind != null) 'target_kind': targetKind,
      if (scope != null) 'scope': scope,
      if (envelope != null) 'envelope': envelope,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (issuedAt != null) 'issued_at': issuedAt,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (attempts != null) 'attempts': attempts,
    });
  }

  QueuedCommandsCompanion copyWith({
    Value<String>? clientCommandId,
    Value<int>? seq,
    Value<String>? type,
    Value<String>? targetId,
    Value<int>? targetKind,
    Value<String>? scope,
    Value<Uint8List>? envelope,
    Value<int?>? expectedVersion,
    Value<DateTime>? issuedAt,
    Value<String>? state,
    Value<String?>? lastError,
    Value<int>? attempts,
  }) {
    return QueuedCommandsCompanion(
      clientCommandId: clientCommandId ?? this.clientCommandId,
      seq: seq ?? this.seq,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      targetKind: targetKind ?? this.targetKind,
      scope: scope ?? this.scope,
      envelope: envelope ?? this.envelope,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      issuedAt: issuedAt ?? this.issuedAt,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientCommandId.present) {
      map['client_command_id'] = Variable<String>(clientCommandId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (targetKind.present) {
      map['target_kind'] = Variable<int>(targetKind.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (issuedAt.present) {
      map['issued_at'] = Variable<DateTime>(issuedAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedCommandsCompanion(')
          ..write('clientCommandId: $clientCommandId, ')
          ..write('seq: $seq, ')
          ..write('type: $type, ')
          ..write('targetId: $targetId, ')
          ..write('targetKind: $targetKind, ')
          ..write('scope: $scope, ')
          ..write('envelope: $envelope, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

abstract class _$QueueDatabase extends GeneratedDatabase {
  _$QueueDatabase(QueryExecutor e) : super(e);
  $QueueDatabaseManager get managers => $QueueDatabaseManager(this);
  late final $QueuedCommandsTable queuedCommands = $QueuedCommandsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [queuedCommands];
}

typedef $$QueuedCommandsTableCreateCompanionBuilder =
    QueuedCommandsCompanion Function({
      required String clientCommandId,
      Value<int> seq,
      required String type,
      required String targetId,
      required int targetKind,
      required String scope,
      required Uint8List envelope,
      Value<int?> expectedVersion,
      required DateTime issuedAt,
      Value<String> state,
      Value<String?> lastError,
      Value<int> attempts,
    });
typedef $$QueuedCommandsTableUpdateCompanionBuilder =
    QueuedCommandsCompanion Function({
      Value<String> clientCommandId,
      Value<int> seq,
      Value<String> type,
      Value<String> targetId,
      Value<int> targetKind,
      Value<String> scope,
      Value<Uint8List> envelope,
      Value<int?> expectedVersion,
      Value<DateTime> issuedAt,
      Value<String> state,
      Value<String?> lastError,
      Value<int> attempts,
    });

class $$QueuedCommandsTableFilterComposer
    extends Composer<_$QueueDatabase, $QueuedCommandsTable> {
  $$QueuedCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientCommandId => $composableBuilder(
    column: $table.clientCommandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get issuedAt => $composableBuilder(
    column: $table.issuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueuedCommandsTableOrderingComposer
    extends Composer<_$QueueDatabase, $QueuedCommandsTable> {
  $$QueuedCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientCommandId => $composableBuilder(
    column: $table.clientCommandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get issuedAt => $composableBuilder(
    column: $table.issuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedCommandsTableAnnotationComposer
    extends Composer<_$QueueDatabase, $QueuedCommandsTable> {
  $$QueuedCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientCommandId => $composableBuilder(
    column: $table.clientCommandId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get targetKind => $composableBuilder(
    column: $table.targetKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get issuedAt =>
      $composableBuilder(column: $table.issuedAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$QueuedCommandsTableTableManager
    extends
        RootTableManager<
          _$QueueDatabase,
          $QueuedCommandsTable,
          QueuedCommand,
          $$QueuedCommandsTableFilterComposer,
          $$QueuedCommandsTableOrderingComposer,
          $$QueuedCommandsTableAnnotationComposer,
          $$QueuedCommandsTableCreateCompanionBuilder,
          $$QueuedCommandsTableUpdateCompanionBuilder,
          (
            QueuedCommand,
            BaseReferences<
              _$QueueDatabase,
              $QueuedCommandsTable,
              QueuedCommand
            >,
          ),
          QueuedCommand,
          PrefetchHooks Function()
        > {
  $$QueuedCommandsTableTableManager(
    _$QueueDatabase db,
    $QueuedCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedCommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientCommandId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> targetKind = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<Uint8List> envelope = const Value.absent(),
                Value<int?> expectedVersion = const Value.absent(),
                Value<DateTime> issuedAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => QueuedCommandsCompanion(
                clientCommandId: clientCommandId,
                seq: seq,
                type: type,
                targetId: targetId,
                targetKind: targetKind,
                scope: scope,
                envelope: envelope,
                expectedVersion: expectedVersion,
                issuedAt: issuedAt,
                state: state,
                lastError: lastError,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                required String clientCommandId,
                Value<int> seq = const Value.absent(),
                required String type,
                required String targetId,
                required int targetKind,
                required String scope,
                required Uint8List envelope,
                Value<int?> expectedVersion = const Value.absent(),
                required DateTime issuedAt,
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => QueuedCommandsCompanion.insert(
                clientCommandId: clientCommandId,
                seq: seq,
                type: type,
                targetId: targetId,
                targetKind: targetKind,
                scope: scope,
                envelope: envelope,
                expectedVersion: expectedVersion,
                issuedAt: issuedAt,
                state: state,
                lastError: lastError,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueuedCommandsTable, QueuedCommand>(table),
                  BaseReferences<
                    _$QueueDatabase,
                    $QueuedCommandsTable,
                    QueuedCommand
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$QueueDatabase,
      $QueuedCommandsTable,
      QueuedCommand,
      $$QueuedCommandsTableFilterComposer,
      $$QueuedCommandsTableOrderingComposer,
      $$QueuedCommandsTableAnnotationComposer,
      $$QueuedCommandsTableCreateCompanionBuilder,
      $$QueuedCommandsTableUpdateCompanionBuilder,
      (
        QueuedCommand,
        BaseReferences<_$QueueDatabase, $QueuedCommandsTable, QueuedCommand>,
      ),
      QueuedCommand,
      PrefetchHooks Function()
    >;

class $QueueDatabaseManager {
  final _$QueueDatabase _db;
  $QueueDatabaseManager(this._db);
  $$QueuedCommandsTableTableManager get queuedCommands =>
      $$QueuedCommandsTableTableManager(_db, _db.queuedCommands);
}
