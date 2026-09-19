import 'dart:typed_data';

import 'package:cbor/cbor.dart';

/// The plaintext inside an envelope: a CBOR map with a `pv` schema version
/// (crypto design doc §5).
///
/// The three rules of §5 live here:
///
/// 1. Fields are only ever added. Setting a field to null writes CBOR null; no
///    setter removes a key.
/// 2. **Unknown fields are preserved on rewrite.** A payload keeps the whole
///    decoded map, so fields this client doesn't know about are written back
///    exactly as they came, whatever newer client added them.
/// 3. Migration is lazy: [pv] is raised to this client's version when it next
///    writes the object, never lowered.
class Payload {
  Payload._(this._fields);

  /// A new, empty payload at schema version [pv].
  factory Payload.create(int pv) =>
      Payload._(CborMap({CborString('pv'): CborSmallInt(pv)}));

  /// Decodes a payload. Throws [FormatException] if it isn't a CBOR map with
  /// an integer `pv`.
  factory Payload.decode(List<int> bytes) {
    final CborValue value;
    try {
      value = cbor.decode(bytes);
    } catch (e) {
      throw FormatException('payload is not CBOR: $e');
    }
    if (value is! CborMap) throw const FormatException('payload is not a map');
    final payload = Payload._(CborMap.of(value));
    if (payload._fields[CborString('pv')] is! CborInt) {
      throw const FormatException('payload has no pv');
    }
    return payload;
  }

  final CborMap _fields;

  int get pv => (_fields[CborString('pv')]! as CborInt).toInt();

  /// Raises the schema version, never lowers it: an old client rewriting a
  /// newer payload keeps the newer `pv`, since the newer fields are still there.
  void upgradeTo(int version) {
    if (version > pv) _fields[CborString('pv')] = CborSmallInt(version);
  }

  bool has(String key) => _fields.containsKey(CborString(key));

  /// Which member last wrote this payload, stamped by the store.
  String? get editedBy => text('editedBy');

  // ---- typed reads: null when absent, null, or of another type --------------

  String? text(String key) => switch (_fields[CborString(key)]) {
    CborString s => s.toString(),
    _ => null,
  };

  int? integer(String key) => switch (_fields[CborString(key)]) {
    CborInt i => i.toInt(),
    _ => null,
  };

  bool? boolean(String key) => switch (_fields[CborString(key)]) {
    CborBool b => b.value,
    _ => null,
  };

  List<String>? texts(String key) => switch (_fields[CborString(key)]) {
    CborList list => [
      for (final item in list)
        if (item is CborString) item.toString(),
    ],
    _ => null,
  };

  /// A nested map, itself preserving unknown fields.
  Payload? nested(String key) => switch (_fields[CborString(key)]) {
    CborMap map => Payload._(map),
    _ => null,
  };

  /// A list of nested maps; items that aren't maps are skipped.
  List<Payload>? nestedList(String key) => switch (_fields[CborString(key)]) {
    CborList list => [
      for (final item in list)
        if (item is CborMap) Payload._(item),
    ],
    _ => null,
  };

  // ---- typed writes: null writes CBOR null, never removes the key ------------

  void setText(String key, String? value) => _fields[CborString(key)] =
      value == null ? const CborNull() : CborString(value);

  void setInteger(String key, int? value) => _fields[CborString(key)] =
      value == null ? const CborNull() : CborSmallInt(value);

  void setBoolean(String key, bool? value) => _fields[CborString(key)] =
      value == null ? const CborNull() : CborBool(value);

  void setTexts(String key, List<String>? value) =>
      _fields[CborString(key)] = value == null
      ? const CborNull()
      : CborList([for (final v in value) CborString(v)]);

  /// Writes a nested map, merging into any existing one so its unknown fields
  /// survive too.
  void setNested(String key, Payload? value) {
    if (value == null) {
      _fields[CborString(key)] = const CborNull();
      return;
    }
    final existing = _fields[CborString(key)];
    if (existing is CborMap) {
      existing.addAll(value._fields);
    } else {
      _fields[CborString(key)] = CborMap.of(value._fields);
    }
  }

  /// Writes a list of nested maps. Each item merges into the existing item at
  /// the same position, so a newer client's fields on it survive a rewrite
  /// that keeps the item.
  void setNestedList(String key, List<Payload>? value) {
    if (value == null) {
      _fields[CborString(key)] = const CborNull();
      return;
    }
    final existing = switch (_fields[CborString(key)]) {
      CborList list => list,
      _ => const <CborValue>[],
    };
    _fields[CborString(key)] = CborList([
      for (final (i, item) in value.indexed)
        if (i < existing.length && existing[i] is CborMap)
          CborMap.of(existing[i] as CborMap)..addAll(item._fields)
        else
          CborMap.of(item._fields),
    ]);
  }

  /// A nested payload with no `pv` of its own.
  static Payload map() => Payload._(CborMap({}));

  Uint8List encode() => Uint8List.fromList(cbor.encode(_fields));
}
