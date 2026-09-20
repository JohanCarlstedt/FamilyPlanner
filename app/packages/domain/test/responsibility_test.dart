import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const anna = Member(
    id: 'anna',
    displayName: 'Anna',
    role: MemberRole.parent,
  );
  const sitter = Member(
    id: 'sitter',
    displayName: 'Bea',
    role: MemberRole.helper,
  );
  const teen = Member(
    id: 'leo',
    displayName: 'Leo',
    role: MemberRole.child,
    tier: MaturityTier.teen,
  );
  const kid = Member(
    id: 'maja',
    displayName: 'Maja',
    role: MemberRole.child,
    tier: MaturityTier.kid,
  );
  const little = Member(
    id: 'tuva',
    displayName: 'Tuva',
    role: MemberRole.child,
    tier: MaturityTier.little,
  );
  const family = [anna, sitter, teen, kid, little];

  List<String> namesFor(List<String> participants) => [
    for (final m in whoCanBeResponsible(family, participants)) m.id,
  ];

  test('adults and helpers can be responsible for anyone', () {
    expect(namesFor(['maja']), containsAll(['anna', 'sitter']));
    expect(namesFor(['tuva', 'maja']), containsAll(['anna', 'sitter']));
  });

  test('a teen can take a younger sibling, as the spec allows', () {
    expect(namesFor(['tuva', 'leo']), contains('leo'));
    expect(namesFor(['tuva']), contains('leo'));
  });

  test('a child can take themselves', () {
    // Maja walking herself to football is an answer to "who is taking her",
    // and the honest one.
    expect(namesFor(['maja']), contains('maja'));
  });

  test('but not a sibling, whatever the parent hoped', () {
    // Two children in it: the younger one cannot be the family's answer for
    // the other. That is what the teen tier is for.
    expect(namesFor(['maja', 'tuva']), isNot(contains('maja')));
    expect(namesFor(['maja', 'tuva']), isNot(contains('tuva')));
  });

  test('someone who has left the family is nobody', () {
    final former = [
      Member(
        id: 'anna',
        displayName: 'Anna',
        role: MemberRole.parent,
        endedAt: DateTime.utc(2026, 1, 1),
      ),
      sitter,
    ];
    expect([
      for (final m in whoCanBeResponsible(former, ['maja'])) m.id,
    ], ['sitter']);
  });

  test('an event with no children still offers the adults', () {
    expect(namesFor(['anna']), contains('anna'));
  });
}
