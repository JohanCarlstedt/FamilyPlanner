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

class $CachedBlobsTable extends CachedBlobs
    with TableInfo<$CachedBlobsTable, CachedBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedBlob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $CachedBlobsTable createAlias(String alias) {
    return $CachedBlobsTable(attachedDatabase, alias);
  }
}

class CachedBlob extends DataClass implements Insertable<CachedBlob> {
  final String id;
  final Uint8List bytes;
  const CachedBlob({required this.id, required this.bytes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  CachedBlobsCompanion toCompanion(bool nullToAbsent) {
    return CachedBlobsCompanion(id: Value(id), bytes: Value(bytes));
  }

  factory CachedBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedBlob(
      id: serializer.fromJson<String>(json['id']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  CachedBlob copyWith({String? id, Uint8List? bytes}) =>
      CachedBlob(id: id ?? this.id, bytes: bytes ?? this.bytes);
  CachedBlob copyWithCompanion(CachedBlobsCompanion data) {
    return CachedBlob(
      id: data.id.present ? data.id.value : this.id,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedBlob(')
          ..write('id: $id, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedBlob &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class CachedBlobsCompanion extends UpdateCompanion<CachedBlob> {
  final Value<String> id;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const CachedBlobsCompanion({
    this.id = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedBlobsCompanion.insert({
    required String id,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bytes = Value(bytes);
  static Insertable<CachedBlob> custom({
    Expression<String>? id,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedBlobsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return CachedBlobsCompanion(
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedBlobsCompanion(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
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
  late final $CachedBlobsTable cachedBlobs = $CachedBlobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedObjects,
    syncState,
    cachedBlobs,
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
typedef $$CachedBlobsTableCreateCompanionBuilder =
    CachedBlobsCompanion Function({
      required String id,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$CachedBlobsTableUpdateCompanionBuilder =
    CachedBlobsCompanion Function({
      Value<String> id,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

class $$CachedBlobsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedBlobsTable> {
  $$CachedBlobsTableFilterComposer({
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

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedBlobsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedBlobsTable> {
  $$CachedBlobsTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedBlobsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedBlobsTable> {
  $$CachedBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);
}

class $$CachedBlobsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedBlobsTable,
          CachedBlob,
          $$CachedBlobsTableFilterComposer,
          $$CachedBlobsTableOrderingComposer,
          $$CachedBlobsTableAnnotationComposer,
          $$CachedBlobsTableCreateCompanionBuilder,
          $$CachedBlobsTableUpdateCompanionBuilder,
          (
            CachedBlob,
            BaseReferences<_$CacheDatabase, $CachedBlobsTable, CachedBlob>,
          ),
          CachedBlob,
          PrefetchHooks Function()
        > {
  $$CachedBlobsTableTableManager(_$CacheDatabase db, $CachedBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<Uint8List> bytes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CachedBlobsCompanion(id: id, bytes: bytes, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required Uint8List bytes,
            Value<int> rowid = const Value.absent(),
          }) => CachedBlobsCompanion.insert(id: id, bytes: bytes, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedBlobsTable, CachedBlob>(table),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedBlobsTable,
                    CachedBlob
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedBlobsTable,
      CachedBlob,
      $$CachedBlobsTableFilterComposer,
      $$CachedBlobsTableOrderingComposer,
      $$CachedBlobsTableAnnotationComposer,
      $$CachedBlobsTableCreateCompanionBuilder,
      $$CachedBlobsTableUpdateCompanionBuilder,
      (
        CachedBlob,
        BaseReferences<_$CacheDatabase, $CachedBlobsTable, CachedBlob>,
      ),
      CachedBlob,
      PrefetchHooks Function()
    >;

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$CachedObjectsTableTableManager get cachedObjects =>
      $$CachedObjectsTableTableManager(_db, _db.cachedObjects);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$CachedBlobsTableTableManager get cachedBlobs =>
      $$CachedBlobsTableTableManager(_db, _db.cachedBlobs);
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

class $DeviceStateTable extends DeviceState
    with TableInfo<$DeviceStateTable, DeviceStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceStateTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<Uint8List> value = GeneratedColumn<Uint8List>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceStateEntry> instance, {
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
  DeviceStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceStateEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceStateTable createAlias(String alias) {
    return $DeviceStateTable(attachedDatabase, alias);
  }
}

class DeviceStateEntry extends DataClass
    implements Insertable<DeviceStateEntry> {
  final String key;
  final Uint8List value;
  const DeviceStateEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<Uint8List>(value);
    return map;
  }

  DeviceStateCompanion toCompanion(bool nullToAbsent) {
    return DeviceStateCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceStateEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<Uint8List>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<Uint8List>(value),
    };
  }

  DeviceStateEntry copyWith({String? key, Uint8List? value}) =>
      DeviceStateEntry(key: key ?? this.key, value: value ?? this.value);
  DeviceStateEntry copyWithCompanion(DeviceStateCompanion data) {
    return DeviceStateEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, $driftBlobEquality.hash(value));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceStateEntry &&
          other.key == this.key &&
          $driftBlobEquality.equals(other.value, this.value));
}

class DeviceStateCompanion extends UpdateCompanion<DeviceStateEntry> {
  final Value<String> key;
  final Value<Uint8List> value;
  final Value<int> rowid;
  const DeviceStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceStateCompanion.insert({
    required String key,
    required Uint8List value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceStateEntry> custom({
    Expression<String>? key,
    Expression<Uint8List>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceStateCompanion copyWith({
    Value<String>? key,
    Value<Uint8List>? value,
    Value<int>? rowid,
  }) {
    return DeviceStateCompanion(
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
      map['value'] = Variable<Uint8List>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, groupId, sender, sentAt, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessageRow extends DataClass implements Insertable<ChatMessageRow> {
  /// The delivery service's sequence number, or a local id until it's sent.
  final String id;
  final String groupId;

  /// The sending device.
  final String sender;
  final DateTime sentAt;

  /// CBOR payload (crypto doc §5 rules): text now, more later.
  final Uint8List payload;
  const ChatMessageRow({
    required this.id,
    required this.groupId,
    required this.sender,
    required this.sentAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['sender'] = Variable<String>(sender);
    map['sent_at'] = Variable<DateTime>(sentAt);
    map['payload'] = Variable<Uint8List>(payload);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      sender: Value(sender),
      sentAt: Value(sentAt),
      payload: Value(payload),
    );
  }

  factory ChatMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessageRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      sender: serializer.fromJson<String>(json['sender']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'sender': serializer.toJson<String>(sender),
      'sentAt': serializer.toJson<DateTime>(sentAt),
      'payload': serializer.toJson<Uint8List>(payload),
    };
  }

  ChatMessageRow copyWith({
    String? id,
    String? groupId,
    String? sender,
    DateTime? sentAt,
    Uint8List? payload,
  }) => ChatMessageRow(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    sender: sender ?? this.sender,
    sentAt: sentAt ?? this.sentAt,
    payload: payload ?? this.payload,
  );
  ChatMessageRow copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessageRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      sender: data.sender.present ? data.sender.value : this.sender,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('sender: $sender, ')
          ..write('sentAt: $sentAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    sender,
    sentAt,
    $driftBlobEquality.hash(payload),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.sender == this.sender &&
          other.sentAt == this.sentAt &&
          $driftBlobEquality.equals(other.payload, this.payload));
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessageRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> sender;
  final Value<DateTime> sentAt;
  final Value<Uint8List> payload;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.sender = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String groupId,
    required String sender,
    required DateTime sentAt,
    required Uint8List payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       sender = Value(sender),
       sentAt = Value(sentAt),
       payload = Value(payload);
  static Insertable<ChatMessageRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? sender,
    Expression<DateTime>? sentAt,
    Expression<Uint8List>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (sender != null) 'sender': sender,
      if (sentAt != null) 'sent_at': sentAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? sender,
    Value<DateTime>? sentAt,
    Value<Uint8List>? payload,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      sender: sender ?? this.sender,
      sentAt: sentAt ?? this.sentAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('sender: $sender, ')
          ..write('sentAt: $sentAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingBlobsTable extends PendingBlobs
    with TableInfo<$PendingBlobsTable, PendingBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, envelope, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('envelope')) {
      context.handle(
        _envelopeMeta,
        envelope.isAcceptableOrUnknown(data['envelope']!, _envelopeMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingBlob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      envelope: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingBlobsTable createAlias(String alias) {
    return $PendingBlobsTable(attachedDatabase, alias);
  }
}

class PendingBlob extends DataClass implements Insertable<PendingBlob> {
  final String id;
  final Uint8List envelope;
  final DateTime createdAt;
  const PendingBlob({
    required this.id,
    required this.envelope,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['envelope'] = Variable<Uint8List>(envelope);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingBlobsCompanion toCompanion(bool nullToAbsent) {
    return PendingBlobsCompanion(
      id: Value(id),
      envelope: Value(envelope),
      createdAt: Value(createdAt),
    );
  }

  factory PendingBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingBlob(
      id: serializer.fromJson<String>(json['id']),
      envelope: serializer.fromJson<Uint8List>(json['envelope']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'envelope': serializer.toJson<Uint8List>(envelope),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingBlob copyWith({
    String? id,
    Uint8List? envelope,
    DateTime? createdAt,
  }) => PendingBlob(
    id: id ?? this.id,
    envelope: envelope ?? this.envelope,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingBlob copyWithCompanion(PendingBlobsCompanion data) {
    return PendingBlob(
      id: data.id.present ? data.id.value : this.id,
      envelope: data.envelope.present ? data.envelope.value : this.envelope,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingBlob(')
          ..write('id: $id, ')
          ..write('envelope: $envelope, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, $driftBlobEquality.hash(envelope), createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingBlob &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.envelope, this.envelope) &&
          other.createdAt == this.createdAt);
}

class PendingBlobsCompanion extends UpdateCompanion<PendingBlob> {
  final Value<String> id;
  final Value<Uint8List> envelope;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingBlobsCompanion({
    this.id = const Value.absent(),
    this.envelope = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingBlobsCompanion.insert({
    required String id,
    required Uint8List envelope,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       envelope = Value(envelope),
       createdAt = Value(createdAt);
  static Insertable<PendingBlob> custom({
    Expression<String>? id,
    Expression<Uint8List>? envelope,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (envelope != null) 'envelope': envelope,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingBlobsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? envelope,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingBlobsCompanion(
      id: id ?? this.id,
      envelope: envelope ?? this.envelope,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (envelope.present) {
      map['envelope'] = Variable<Uint8List>(envelope.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingBlobsCompanion(')
          ..write('id: $id, ')
          ..write('envelope: $envelope, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$QueueDatabase extends GeneratedDatabase {
  _$QueueDatabase(QueryExecutor e) : super(e);
  $QueueDatabaseManager get managers => $QueueDatabaseManager(this);
  late final $QueuedCommandsTable queuedCommands = $QueuedCommandsTable(this);
  late final $DeviceStateTable deviceState = $DeviceStateTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $PendingBlobsTable pendingBlobs = $PendingBlobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    queuedCommands,
    deviceState,
    chatMessages,
    pendingBlobs,
  ];
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
typedef $$DeviceStateTableCreateCompanionBuilder =
    DeviceStateCompanion Function({
      required String key,
      required Uint8List value,
      Value<int> rowid,
    });
typedef $$DeviceStateTableUpdateCompanionBuilder =
    DeviceStateCompanion Function({
      Value<String> key,
      Value<Uint8List> value,
      Value<int> rowid,
    });

class $$DeviceStateTableFilterComposer
    extends Composer<_$QueueDatabase, $DeviceStateTable> {
  $$DeviceStateTableFilterComposer({
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

  ColumnFilters<Uint8List> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceStateTableOrderingComposer
    extends Composer<_$QueueDatabase, $DeviceStateTable> {
  $$DeviceStateTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceStateTableAnnotationComposer
    extends Composer<_$QueueDatabase, $DeviceStateTable> {
  $$DeviceStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<Uint8List> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceStateTableTableManager
    extends
        RootTableManager<
          _$QueueDatabase,
          $DeviceStateTable,
          DeviceStateEntry,
          $$DeviceStateTableFilterComposer,
          $$DeviceStateTableOrderingComposer,
          $$DeviceStateTableAnnotationComposer,
          $$DeviceStateTableCreateCompanionBuilder,
          $$DeviceStateTableUpdateCompanionBuilder,
          (
            DeviceStateEntry,
            BaseReferences<
              _$QueueDatabase,
              $DeviceStateTable,
              DeviceStateEntry
            >,
          ),
          DeviceStateEntry,
          PrefetchHooks Function()
        > {
  $$DeviceStateTableTableManager(_$QueueDatabase db, $DeviceStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<Uint8List> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DeviceStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required Uint8List value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceStateTable, DeviceStateEntry>(table),
                  BaseReferences<
                    _$QueueDatabase,
                    $DeviceStateTable,
                    DeviceStateEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceStateTableProcessedTableManager =
    ProcessedTableManager<
      _$QueueDatabase,
      $DeviceStateTable,
      DeviceStateEntry,
      $$DeviceStateTableFilterComposer,
      $$DeviceStateTableOrderingComposer,
      $$DeviceStateTableAnnotationComposer,
      $$DeviceStateTableCreateCompanionBuilder,
      $$DeviceStateTableUpdateCompanionBuilder,
      (
        DeviceStateEntry,
        BaseReferences<_$QueueDatabase, $DeviceStateTable, DeviceStateEntry>,
      ),
      DeviceStateEntry,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String groupId,
      required String sender,
      required DateTime sentAt,
      required Uint8List payload,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> sender,
      Value<DateTime> sentAt,
      Value<Uint8List> payload,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$QueueDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$QueueDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$QueueDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$QueueDatabase,
          $ChatMessagesTable,
          ChatMessageRow,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessageRow,
            BaseReferences<_$QueueDatabase, $ChatMessagesTable, ChatMessageRow>,
          ),
          ChatMessageRow,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$QueueDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                groupId: groupId,
                sender: sender,
                sentAt: sentAt,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String sender,
                required DateTime sentAt,
                required Uint8List payload,
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                groupId: groupId,
                sender: sender,
                sentAt: sentAt,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessageRow>(table),
                  BaseReferences<
                    _$QueueDatabase,
                    $ChatMessagesTable,
                    ChatMessageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$QueueDatabase,
      $ChatMessagesTable,
      ChatMessageRow,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessageRow,
        BaseReferences<_$QueueDatabase, $ChatMessagesTable, ChatMessageRow>,
      ),
      ChatMessageRow,
      PrefetchHooks Function()
    >;
typedef $$PendingBlobsTableCreateCompanionBuilder =
    PendingBlobsCompanion Function({
      required String id,
      required Uint8List envelope,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingBlobsTableUpdateCompanionBuilder =
    PendingBlobsCompanion Function({
      Value<String> id,
      Value<Uint8List> envelope,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingBlobsTableFilterComposer
    extends Composer<_$QueueDatabase, $PendingBlobsTable> {
  $$PendingBlobsTableFilterComposer({
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

  ColumnFilters<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingBlobsTableOrderingComposer
    extends Composer<_$QueueDatabase, $PendingBlobsTable> {
  $$PendingBlobsTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get envelope => $composableBuilder(
    column: $table.envelope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingBlobsTableAnnotationComposer
    extends Composer<_$QueueDatabase, $PendingBlobsTable> {
  $$PendingBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get envelope =>
      $composableBuilder(column: $table.envelope, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingBlobsTableTableManager
    extends
        RootTableManager<
          _$QueueDatabase,
          $PendingBlobsTable,
          PendingBlob,
          $$PendingBlobsTableFilterComposer,
          $$PendingBlobsTableOrderingComposer,
          $$PendingBlobsTableAnnotationComposer,
          $$PendingBlobsTableCreateCompanionBuilder,
          $$PendingBlobsTableUpdateCompanionBuilder,
          (
            PendingBlob,
            BaseReferences<_$QueueDatabase, $PendingBlobsTable, PendingBlob>,
          ),
          PendingBlob,
          PrefetchHooks Function()
        > {
  $$PendingBlobsTableTableManager(_$QueueDatabase db, $PendingBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> envelope = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingBlobsCompanion(
                id: id,
                envelope: envelope,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List envelope,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingBlobsCompanion.insert(
                id: id,
                envelope: envelope,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingBlobsTable, PendingBlob>(table),
                  BaseReferences<
                    _$QueueDatabase,
                    $PendingBlobsTable,
                    PendingBlob
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$QueueDatabase,
      $PendingBlobsTable,
      PendingBlob,
      $$PendingBlobsTableFilterComposer,
      $$PendingBlobsTableOrderingComposer,
      $$PendingBlobsTableAnnotationComposer,
      $$PendingBlobsTableCreateCompanionBuilder,
      $$PendingBlobsTableUpdateCompanionBuilder,
      (
        PendingBlob,
        BaseReferences<_$QueueDatabase, $PendingBlobsTable, PendingBlob>,
      ),
      PendingBlob,
      PrefetchHooks Function()
    >;

class $QueueDatabaseManager {
  final _$QueueDatabase _db;
  $QueueDatabaseManager(this._db);
  $$QueuedCommandsTableTableManager get queuedCommands =>
      $$QueuedCommandsTableTableManager(_db, _db.queuedCommands);
  $$DeviceStateTableTableManager get deviceState =>
      $$DeviceStateTableTableManager(_db, _db.deviceState);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$PendingBlobsTableTableManager get pendingBlobs =>
      $$PendingBlobsTableTableManager(_db, _db.pendingBlobs);
}
