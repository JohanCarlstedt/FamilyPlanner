import 'payload.dart';

/// A calendar feed linked to a member (docs/roadmap.md "Integrations"): the
/// first integration module. Sealed to `adults`; a parent's device fetches
/// the feed itself, so the server never learns which team a child is in.
class CalendarLinkPayload {
  CalendarLinkPayload._(this.payload);

  static const version = 1;

  factory CalendarLinkPayload.read(Payload payload) =>
      CalendarLinkPayload._(payload);

  factory CalendarLinkPayload.write({
    Payload? existing,
    required String memberId,
    required String name,
    required String url,
    String? responsibleMemberId,
  }) {
    final p = existing ?? Payload.create(version);
    p.upgradeTo(version);
    p
      ..setText('module', 'ical')
      ..setText('member', memberId)
      ..setText('name', name)
      ..setText('url', url)
      ..setText('responsible', responsibleMemberId);
    return CalendarLinkPayload._(p);
  }

  final Payload payload;

  /// Which integration this is; `ical` for now.
  String get module => payload.text('module') ?? 'ical';
  String get memberId => payload.text('member') ?? '';
  String get name => payload.text('name') ?? '';
  String get url => payload.text('url') ?? '';

  /// Who usually takes the member there: set on events that have no one
  /// responsible, never over what the family chose.
  String? get responsibleMemberId => payload.text('responsible');
}

/// Turns what a person pastes into a fetchable feed URL: a `webcal://`
/// link, an `https://…ics`, or a laget.se team page (whose feed is
/// `cal.laget.se/<team>.ics`). Null if it isn't any of those.
String? feedUrl(String input) {
  final text = input.trim();
  final uri = Uri.tryParse(
    text.startsWith('webcal://')
        ? 'https://${text.substring('webcal://'.length)}'
        : text,
  );
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final host = uri.host.toLowerCase();
  if ((host == 'www.laget.se' || host == 'laget.se') &&
      uri.pathSegments.isNotEmpty &&
      !uri.path.endsWith('.ics')) {
    return 'https://cal.laget.se/${uri.pathSegments.first}.ics';
  }
  return uri.replace(scheme: 'https').toString();
}
