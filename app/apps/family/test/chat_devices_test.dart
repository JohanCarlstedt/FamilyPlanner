import 'package:domain/domain.dart';
import 'package:family/src/chat/chat_providers.dart';
import 'package:flutter_test/flutter_test.dart';

DirectoryDevice device(
  String id,
  String member, {
  bool revoked = false,
  String platform = 'ios',
}) => (deviceId: id, memberId: member, revoked: revoked, platform: platform);

void main() {
  final members = [
    const Member(id: 'anna', displayName: 'Anna', role: MemberRole.parent),
    const Member(id: 'maja', displayName: 'Maja', role: MemberRole.child),
    const Member(id: 'nils', displayName: 'Nils', role: MemberRole.child),
    const Member(id: 'sara', displayName: 'Sara', role: MemberRole.helper),
  ];
  final directory = [
    device('anna-phone', 'anna'),
    device('anna-old', 'anna', revoked: true),
    device('anna-kit', 'anna', platform: 'recovery'),
    device('kitchen', 'anna', platform: 'kitchen'),
    device('maja-tablet', 'maja'),
    device('maja-new', 'maja'), // Paired on the other parent's phone.
    device('nils-phone', 'nils'),
    device('sara-phone', 'sara'),
    device('someone', 'not-synced-yet'),
  ];
  final devices = ChatDevices.from(
    directory,
    members: members,
    trusted: {'anna-phone', 'maja-tablet', 'nils-phone', 'sara-phone'},
  );

  test('only trusted devices of people who chat may be added', () {
    expect(devices.all, {'anna-phone', 'maja-tablet', 'nils-phone'});
    expect(devices.of({'anna', 'maja'}), {'anna-phone', 'maja-tablet'});
  });

  test('a device not trusted here yet is never removed for it', () {
    // The tug-of-war: one parent's phone threw out what the other's had
    // just added, every sync, spending a key package each time.
    expect(devices.outside({'anna', 'maja'}), isNot(contains('maja-new')));
    expect(devices.barred, isNot(contains('maja-new')));
  });

  test('nor is one whose member this phone has not heard of', () {
    expect(devices.outside({'anna'}), isNot(contains('someone')));
  });

  test('what is known not to belong goes', () {
    expect(devices.barred, {'anna-old', 'anna-kit', 'kitchen', 'sara-phone'});
    expect(devices.outside({'anna', 'maja'}), {
      ...devices.barred,
      'nils-phone',
    });
    // Not a reader: out, whether this phone trusts the device or not.
    expect(devices.outside({'anna'}), containsAll(['maja-tablet', 'maja-new']));
  });
}
