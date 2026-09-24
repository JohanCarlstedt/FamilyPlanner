import 'package:domain/domain.dart';

import 'payload.dart';

/// One child offering another a swap of goods (kind 32, sealed to `all`):
/// what each gives, how many, and how it was answered. Parents can read
/// it like everything else the children's cities are counted from.
class TradePayload {
  TradePayload._(this.payload);

  static const version = 1;

  factory TradePayload.read(Payload payload) => TradePayload._(payload);

  /// A new offer from [from] to [to]: [count] of [give] for [count] of
  /// [get]. Always the same number both ways: the family chose even
  /// trades only.
  factory TradePayload.offer({
    required String from,
    required String to,
    required Good give,
    required Good get,
    required int count,
    required DateTime at,
  }) => TradePayload._(
    Payload.create(version)
      ..setText('from', from)
      ..setText('to', to)
      ..setText('give', give.name)
      ..setText('get', get.name)
      ..setInteger('count', count)
      ..setText('state', TradeState.offered.name)
      ..setText('offeredAt', at.toUtc().toIso8601String()),
  );

  final Payload payload;

  String get from => payload.text('from') ?? '';
  String get to => payload.text('to') ?? '';
  Good? get give => Good.values.asNameMap()[payload.text('give')];
  Good? get get => Good.values.asNameMap()[payload.text('get')];
  int get count => payload.integer('count') ?? 0;
  TradeState get state =>
      TradeState.values.asNameMap()[payload.text('state')] ??
      TradeState.offered;
  DateTime? get offeredAt => DateTime.tryParse(payload.text('offeredAt') ?? '');
  DateTime? get answeredAt =>
      DateTime.tryParse(payload.text('answeredAt') ?? '');
  String? get answeredBy => payload.text('answeredBy');

  bool get isOpen => state == TradeState.offered;

  /// Accepted, declined or taken back, by [by]. Unknown fields stay.
  TradePayload answered(TradeState state, {required String by, DateTime? at}) =>
      TradePayload._(
        Payload.decode(payload.encode())
          ..setText('state', state.name)
          ..setText('answeredBy', by)
          ..setText(
            'answeredAt',
            (at ?? DateTime.now()).toUtc().toIso8601String(),
          ),
      );

  /// As the ledger counts it, or null if a later version wrote goods this
  /// one does not know.
  Trade? toTrade(String id) => switch ((give, get, offeredAt)) {
    (final give?, final get?, final offeredAt?) => Trade(
      id: id,
      from: from,
      to: to,
      give: give,
      get: get,
      count: count,
      state: state,
      offeredAt: offeredAt,
      answeredAt: answeredAt,
      answeredBy: answeredBy,
    ),
    _ => null,
  };
}
