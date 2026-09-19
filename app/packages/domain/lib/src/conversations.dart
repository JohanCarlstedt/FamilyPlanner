import 'family.dart';
import 'family_settings.dart';

/// Who can read a direct or group conversation (spec §6 "Supervision becomes
/// key membership"): its participants, and, when a child in it is at or
/// below the family's supervised tier, every parent too. The readers are the
/// key list, so this is also who the thread says can read it.
class ConversationAudience {
  const ConversationAudience._(this.participants, this.supervisors);

  factory ConversationAudience.of({
    required Set<String> participants,
    required List<Member> members,
    required FamilySettings settings,
  }) {
    final byId = {for (final m in members) m.id: m};
    final present = {
      for (final id in participants)
        if (byId[id] case final m? when m.isActive && !_isHelper(m)) id,
    };
    final upTo = settings.superviseMessagesUpTo;
    final supervised =
        upTo != null &&
        present.any((id) {
          final m = byId[id]!;
          return m.isChild &&
              (m.tier ?? MaturityTier.little).index <= upTo.index;
        });
    return ConversationAudience._(present, {
      if (supervised)
        for (final m in members)
          if (m.isParent && m.isActive && !present.contains(m.id)) m.id,
    });
  }

  /// The members talking, as far as they're still in the family.
  final Set<String> participants;

  /// Parents reading because a child in it is supervised; not talking.
  final Set<String> supervisors;

  bool get isSupervised => supervisors.isNotEmpty;

  Set<String> get readers => {...participants, ...supervisors};
}

bool _isHelper(Member m) => m.role == MemberRole.helper || m.isCoParent;

/// Spec §6: chat is for the family. Helpers and co-parents have their own
/// ways in (the calendar they cover) and no threads yet.
bool canMessage(Member from, Member to) =>
    from.id != to.id &&
    from.isActive &&
    to.isActive &&
    !_isHelper(from) &&
    !_isHelper(to);

/// Spec §6: direct conversations are keyed on the sorted pair, so two
/// people never end up with two threads.
String directKey(String a, String b) {
  final pair = [a, b]..sort();
  return pair.join('/');
}
