import 'payload.dart';

enum SuggestionState { open, scheduled, declined }

/// A meal someone would like (spec §4 `meal_suggestion`, kind 18). Open
/// suggestions expire, so the pool doesn't become a graveyard.
class MealSuggestionPayload {
  MealSuggestionPayload._(this.payload);

  static const version = 1;
  static const lifetime = Duration(days: 60);

  factory MealSuggestionPayload.read(Payload payload) =>
      MealSuggestionPayload._(payload);

  factory MealSuggestionPayload.write({
    Payload? existing,
    required String suggestedBy,
    String? recipeId,
    String? title,
    String? note,
    SuggestionState state = SuggestionState.open,
    required DateTime expiresAt,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('by', suggestedBy)
      ..setText('recipe', recipeId)
      ..setText('title', title)
      ..setText('note', note)
      ..setText('state', state.name)
      ..setText('expires', expiresAt.toUtc().toIso8601String());
    return MealSuggestionPayload._(p);
  }

  final Payload payload;

  String get suggestedBy => payload.text('by') ?? '';
  String? get recipeId => payload.text('recipe');
  String? get title => payload.text('title');
  String? get note => payload.text('note');
  SuggestionState get state =>
      SuggestionState.values.asNameMap()[payload.text('state')] ??
      SuggestionState.open;
  DateTime? get expiresAt => DateTime.tryParse(payload.text('expires') ?? '');

  bool openAt(DateTime now) =>
      state == SuggestionState.open &&
      (expiresAt == null || expiresAt!.isAfter(now));

  MealSuggestionPayload withState(SuggestionState state) {
    final p = Payload.decode(payload.encode())..setText('state', state.name);
    return MealSuggestionPayload._(p);
  }
}

/// One option in a poll: a recipe or just a name, and who put it forward.
class MealPollOption {
  const MealPollOption({
    required this.id,
    required this.proposer,
    this.recipeId,
    this.title,
    this.suggestionId,
  });

  final String id;
  final String proposer;
  final String? recipeId;
  final String? title;
  final String? suggestionId;

  Payload toPayload() => Payload.map()
    ..setText('id', id)
    ..setText('by', proposer)
    ..setText('recipe', recipeId)
    ..setText('title', title)
    ..setText('suggestion', suggestionId);

  static MealPollOption read(Payload p) => MealPollOption(
    id: p.text('id') ?? '',
    proposer: p.text('by') ?? '',
    recipeId: p.text('recipe'),
    title: p.text('title'),
    suggestionId: p.text('suggestion'),
  );
}

enum PollState { open, closed, cancelled }

/// A meal poll (spec §4 `meal_poll`, kind 19): which dinner, the options,
/// who may vote (fixed when it opens), and, once closed, what won and
/// whether a parent overrode it, for everyone to see.
class MealPollPayload {
  MealPollPayload._(this.payload);

  static const version = 1;

  factory MealPollPayload.read(Payload payload) => MealPollPayload._(payload);

  factory MealPollPayload.write({
    Payload? existing,
    required String title,
    required DateTime date,
    required DateTime closesAt,
    required List<MealPollOption> options,
    required List<String> eligible,
    required String createdBy,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('title', title)
      ..setText('date', _date(date))
      ..setText('closes', closesAt.toUtc().toIso8601String())
      ..setText('method', 'approval')
      ..setText('state', PollState.open.name)
      ..setTexts('eligible', eligible)
      ..setText('by', createdBy)
      ..setNestedList('options', [for (final o in options) o.toPayload()]);
    return MealPollPayload._(p);
  }

  final Payload payload;

  String get title => payload.text('title') ?? '';
  DateTime? get date => DateTime.tryParse('${payload.text('date')}T00:00:00Z');
  DateTime? get closesAt => DateTime.tryParse(payload.text('closes') ?? '');
  PollState get state =>
      PollState.values.asNameMap()[payload.text('state')] ?? PollState.open;
  List<String> get eligible => payload.texts('eligible') ?? const [];
  String get createdBy => payload.text('by') ?? '';
  List<MealPollOption> get options => [
    for (final o in payload.nestedList('options') ?? const <Payload>[])
      MealPollOption.read(o),
  ];

  /// The option chosen when it closed.
  String? get winner => payload.text('winner');

  /// What the vote said, when a parent chose otherwise.
  String? get votedWinner => payload.text('voted');

  /// The parent who overrode the vote, shown with the result.
  String? get overriddenBy => payload.text('overriddenBy');
  DateTime? get closedAt => DateTime.tryParse(payload.text('closed') ?? '');

  MealPollPayload closed({
    required String? winner,
    required String? votedWinner,
    required DateTime at,
    String? overriddenBy,
  }) {
    final p = Payload.decode(payload.encode())
      ..setText('state', PollState.closed.name)
      ..setText('winner', winner)
      ..setText('voted', votedWinner)
      ..setText('overriddenBy', overriddenBy)
      ..setText('closed', at.toUtc().toIso8601String());
    return MealPollPayload._(p);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// One member's ticks in one poll (spec §4 `meal_vote`, kind 20). One
/// object per member and poll, so voting again replaces the old ticks.
class MealVotePayload {
  MealVotePayload._(this.payload);

  static const version = 1;

  factory MealVotePayload.read(Payload payload) => MealVotePayload._(payload);

  factory MealVotePayload.write({
    required String pollId,
    required String memberId,
    required Set<String> options,
  }) {
    final p = Payload.create(version)
      ..setText('poll', pollId)
      ..setText('member', memberId)
      ..setTexts('options', options.toList()..sort());
    return MealVotePayload._(p);
  }

  final Payload payload;

  String get pollId => payload.text('poll') ?? '';
  String get memberId => payload.text('member') ?? '';
  Set<String> get options => {...?payload.texts('options')};
}
