import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// The password list's items as stored: kinds beyond logins, kept readable
/// by an app that knows only logins.
void main() {
  final day = DateTime.utc(2026, 10, 10, 12);

  test('a card keeps its number where an older app looks for a secret', () {
    final card = CredentialPayload.write(
      title: 'Visa',
      secret: '4111 1111 1111 1111',
      scope: const PasswordFor.family(),
      type: VaultItemType.card,
      fields: {'holder': 'Anna Svensson', 'expiry': '09/29', 'cvc': '123'},
      folder: 'Bank',
      favourite: true,
      now: day,
    );
    final read = CredentialPayload.read(Payload.decode(card.payload.encode()));
    expect(read.type, VaultItemType.card);
    expect(read.secret, '4111 1111 1111 1111', reason: 'the main field');
    expect(read.field('number'), '4111 1111 1111 1111');
    expect(read.field('holder'), 'Anna Svensson');
    expect(read.field('cvc'), '123');
    expect(read.folder, 'Bank');
    expect(read.favourite, isTrue);
    expect(read.changedAt, day);
  });

  test('a login is stored exactly as before', () {
    final login = CredentialPayload.write(
      title: 'Netflix',
      secret: 'kT7#mq9!Lp2x',
      username: 'anna@example.com',
      url: 'netflix.com',
      scope: const PasswordFor.family(),
    );
    expect(login.payload.text('type'), isNull);
    expect(login.field('username'), 'anna@example.com');
    expect(login.field('password'), 'kT7#mq9!Lp2x');
    expect(login.field('url'), 'netflix.com');
  });

  test('a changed password keeps the old ones, the last five', () {
    var item = CredentialPayload.write(
      title: 'Mail',
      secret: 'first-one-1!',
      scope: const PasswordFor.family(),
      now: day,
    );
    for (var i = 2; i <= 7; i++) {
      item = CredentialPayload.write(
        existing: item.payload,
        title: 'Mail',
        secret: 'number-$i-x!',
        scope: const PasswordFor.family(),
        now: day.add(Duration(days: i)),
      );
    }
    expect(item.history, hasLength(5));
    expect(item.history.first.secret, 'number-6-x!');
    expect(item.changedAt, day.add(const Duration(days: 7)));
  });

  test('saving with the same password changes neither history nor date', () {
    final first = CredentialPayload.write(
      title: 'Mail',
      secret: 'same-one-1!',
      scope: const PasswordFor.family(),
      now: day,
    );
    final again = CredentialPayload.write(
      existing: first.payload,
      title: 'Mail (renamed)',
      secret: 'same-one-1!',
      scope: const PasswordFor.family(),
      now: day.add(const Duration(days: 30)),
    );
    expect(again.history, isEmpty);
    expect(again.changedAt, day);
  });

  test('a field a later version added survives a rewrite', () {
    final first = CredentialPayload.write(
      title: 'Card',
      secret: '4111',
      scope: const PasswordFor.family(),
      type: VaultItemType.card,
      fields: {'holder': 'Anna'},
    );
    first.payload.nested('fields')!.setText('issuer', 'Bank X');
    first.payload.setNested('fields', first.payload.nested('fields'));
    final again = CredentialPayload.write(
      existing: first.payload,
      title: 'Card',
      secret: '4111',
      scope: const PasswordFor.family(),
      type: VaultItemType.card,
      fields: {'holder': 'Anna S'},
    );
    expect(again.payload.nested('fields')!.text('issuer'), 'Bank X');
    expect(again.field('holder'), 'Anna S');
  });
}
