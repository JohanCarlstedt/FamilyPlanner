import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const anna = Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent);
  const erik = Member(id: 'erik', displayName: 'Erik', role: MemberRole.parent);
  const maja = Member(
    id: 'maja',
    displayName: 'Maja',
    role: MemberRole.child,
    tier: MaturityTier.kid,
  );
  const olle = Member(
    id: 'olle',
    displayName: 'Olle',
    role: MemberRole.child,
    tier: MaturityTier.teen,
  );
  const sitter = Member(
    id: 'sitter',
    displayName: 'Sara',
    role: MemberRole.helper,
  );
  const family = [anna, erik, maja, olle, sitter];

  ConversationAudience audience(
    Set<String> participants, {
    MaturityTier? upTo = MaturityTier.kid,
  }) => ConversationAudience.of(
    participants: participants,
    members: family,
    settings: FamilySettings(superviseMessagesUpTo: upTo),
  );

  group('supervision (spec §6, per family setting)', () {
    test('a supervised child brings the parents in', () {
      final a = audience({'maja', 'olle'});
      expect(a.isSupervised, isTrue);
      expect(a.supervisors, {'anna', 'erik'});
      expect(a.readers, {'maja', 'olle', 'anna', 'erik'});
    });

    test('a parent already talking still has the other one reading', () {
      final a = audience({'maja', 'anna'});
      expect(a.supervisors, {'erik'});
      expect(a.readers, {'maja', 'anna', 'erik'});
    });

    test('above the tier, the conversation is private', () {
      final a = audience({'olle', 'anna'});
      expect(a.isSupervised, isFalse);
      expect(a.readers, {'olle', 'anna'});
    });

    test('off, nobody is supervised; all children, a teen is too', () {
      expect(audience({'maja', 'olle'}, upTo: null).isSupervised, isFalse);
      expect(
        audience({'olle', 'erik'}, upTo: MaturityTier.teen).supervisors,
        {'anna'},
      );
    });

    test('a child with no tier set counts as the youngest', () {
      final a = ConversationAudience.of(
        participants: {'baby', 'olle'},
        members: [
          ...family,
          const Member(id: 'baby', displayName: 'B', role: MemberRole.child),
        ],
        settings: const FamilySettings(
          superviseMessagesUpTo: MaturityTier.little,
        ),
      );
      expect(a.isSupervised, isTrue);
    });

    test('former members and helpers are never in it', () {
      final a = ConversationAudience.of(
        participants: {'maja', 'sitter', 'gone'},
        members: [
          ...family,
          Member(
            id: 'gone',
            displayName: 'G',
            role: MemberRole.child,
            endedAt: DateTime.utc(2026),
          ),
        ],
        settings: FamilySettings.defaults,
      );
      expect(a.readers, {'maja', 'anna', 'erik'});
    });
  });

  group('who may talk to whom', () {
    test('family members, not helpers', () {
      expect(canMessage(maja, olle), isTrue);
      expect(canMessage(anna, maja), isTrue);
      expect(canMessage(maja, sitter), isFalse);
      expect(canMessage(sitter, anna), isFalse);
      expect(canMessage(maja, maja), isFalse);
    });
  });

  test('a direct conversation is keyed on the sorted pair', () {
    expect(directKey('maja', 'anna'), directKey('anna', 'maja'));
    expect(directKey('maja', 'anna'), isNot(directKey('maja', 'erik')));
  });
}
