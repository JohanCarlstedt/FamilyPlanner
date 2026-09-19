import 'payload.dart';

enum RequestState { pending, approved, rejected }

/// "Can I…?" (spec §3 `approval_request`, kind 25): a child asks, a parent
/// answers, and the child sees the answer.
class RequestPayload {
  RequestPayload._(this.payload);

  static const version = 1;

  factory RequestPayload.read(Payload payload) => RequestPayload._(payload);

  factory RequestPayload.write({
    required String requestedBy,
    required String message,
    required DateTime at,
    String subjectType = 'question',
    String? subjectId,
  }) => RequestPayload._(
    Payload.create(version)
      ..setText('by', requestedBy)
      ..setText('message', message)
      ..setText('at', at.toUtc().toIso8601String())
      ..setText('subjectType', subjectType)
      ..setText('subject', subjectId)
      ..setText('state', RequestState.pending.name),
  );

  final Payload payload;

  String get requestedBy => payload.text('by') ?? '';
  String get message => payload.text('message') ?? '';
  DateTime? get at => DateTime.tryParse(payload.text('at') ?? '');
  RequestState get state =>
      RequestState.values.asNameMap()[payload.text('state')] ??
      RequestState.pending;
  String? get decidedBy => payload.text('decidedBy');
  DateTime? get decidedAt => DateTime.tryParse(payload.text('decidedAt') ?? '');

  /// The parent's few words with the answer.
  String? get answer => payload.text('answer');

  RequestPayload decided({
    required bool approved,
    required String by,
    required DateTime at,
    String? answer,
  }) => RequestPayload._(
    Payload.decode(payload.encode())
      ..setText(
        'state',
        (approved ? RequestState.approved : RequestState.rejected).name,
      )
      ..setText('decidedBy', by)
      ..setText('decidedAt', at.toUtc().toIso8601String())
      ..setText('answer', answer),
  );
}
