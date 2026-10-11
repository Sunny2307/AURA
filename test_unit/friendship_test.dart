/// Pure-Dart tests for the friendship model.
///
/// These live in `test_unit/` rather than `test/`, and import `package:test`
/// rather than `package:flutter_test`, for one practical reason: Windows
/// Application Control on this machine blocks `flutter_tester.exe`, so
/// `flutter test` cannot load *any* test file. Nothing here needs a widget tree
/// or a Flutter binding, so running them on the plain Dart VM with
/// `dart test test_unit` gives real, observed coverage of the logic that the
/// security rules are mirrored against — instead of tests that are written but
/// never run.
///
/// Widget tests stay in `test/` and remain blocked until the policy changes or
/// they move to CI.
library;

import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/models/public_profile.dart';
import 'package:test/test.dart';

void main() {
  group('pairIdFor', () {
    test('is the same whichever way round the two uids are given', () {
      // The whole point. Two people requesting each other at the same instant
      // must collide on one document rather than create two friendships.
      expect(
        Friendship.pairIdFor('alice', 'bob'),
        Friendship.pairIdFor('bob', 'alice'),
      );
    });

    test('sorts the uids into the id', () {
      expect(Friendship.pairIdFor('bob', 'alice'), 'alice_bob');
    });

    test('matches what the security rules derive', () {
      // The rules build the id as `members[0] + '_' + members[1]` after
      // requiring `members[0] < members[1]`. This asserts the client agrees,
      // because a mismatch means every write is rejected with a bare
      // permission error that looks like a rules bug.
      const a = 'Xk29fLmQ0aBcDeFgHiJkLmNoPq01';
      const b = 'aB3dEfGh5iJkLmNoPqRsTuVw6789';
      final members = [a, b]..sort();
      expect(Friendship.pairIdFor(a, b), '${members[0]}_${members[1]}');
      expect(members[0].compareTo(members[1]) < 0, isTrue);
    });

    test('uppercase sorts before lowercase, as byte order does', () {
      // Firebase Auth uids are [A-Za-z0-9]. Within ASCII, Dart's UTF-16
      // compareTo and Firestore rules' UTF-8 `<` agree, which is what makes
      // deriving the id on both sides safe.
      expect(Friendship.pairIdFor('Zed', 'alice'), 'Zed_alice');
    });
  });

  group('fromMap', () {
    DateTime parseEpochMillis(Object? value) => switch (value) {
      final int v => DateTime.fromMillisecondsSinceEpoch(v, isUtc: true),
      _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    };

    Friendship build(Map<String, Object?> map) => Friendship.fromMap(
      'alice_bob',
      map,
      parseTimestamp: parseEpochMillis,
    );

    test('reads a pending request', () {
      final friendship = build(const {
        Friendship.fieldMembers: ['alice', 'bob'],
        Friendship.fieldRequestedBy: 'alice',
        Friendship.fieldStatus: 'pending',
        Friendship.fieldCreatedAt: 1756900000000,
        Friendship.fieldRespondedAt: null,
      });

      expect(friendship.status, FriendshipStatus.pending);
      expect(friendship.requestedBy, 'alice');
      expect(friendship.respondedAt, isNull);
      expect(friendship.members, ['alice', 'bob']);
    });

    test('an unknown status reads as pending, never as accepted', () {
      // The safe direction. A corrupt or newer-version document must not be
      // read as consent that was never given.
      final friendship = build(const {
        Friendship.fieldMembers: ['alice', 'bob'],
        Friendship.fieldRequestedBy: 'alice',
        Friendship.fieldStatus: 'something_else',
        Friendship.fieldCreatedAt: 0,
      });

      expect(friendship.status, FriendshipStatus.pending);
    });

    test('a missing status reads as pending', () {
      final friendship = build(const {
        Friendship.fieldMembers: ['alice', 'bob'],
        Friendship.fieldRequestedBy: 'alice',
        Friendship.fieldCreatedAt: 0,
      });

      expect(friendship.status, FriendshipStatus.pending);
    });

    test('a malformed members list does not crash the screen', () {
      final friendship = build(const {
        Friendship.fieldMembers: 'not a list',
        Friendship.fieldRequestedBy: 42,
        Friendship.fieldCreatedAt: 0,
      });

      expect(friendship.members, isEmpty);
      expect(friendship.requestedBy, '');
    });

    test('non-string entries are dropped from members', () {
      final friendship = build(const {
        Friendship.fieldMembers: ['alice', 7, null, 'bob'],
        Friendship.fieldRequestedBy: 'alice',
        Friendship.fieldCreatedAt: 0,
      });

      expect(friendship.members, ['alice', 'bob']);
    });
  });

  group('direction', () {
    Friendship pending({required String requestedBy}) => Friendship(
      id: 'alice_bob',
      members: const ['alice', 'bob'],
      requestedBy: requestedBy,
      status: FriendshipStatus.pending,
      createdAt: DateTime.utc(2026, 10, 3),
      respondedAt: null,
    );

    test('a request you did not send is incoming', () {
      expect(pending(requestedBy: 'alice').isIncomingFor('bob'), isTrue);
      expect(pending(requestedBy: 'alice').isOutgoingFor('bob'), isFalse);
    });

    test('a request you sent is outgoing, and not yours to accept', () {
      // Mirrors the security rule: the sender cannot accept their own request.
      // If this ever disagreed with the rules, the UI would offer an Accept
      // button that always failed.
      expect(pending(requestedBy: 'alice').isOutgoingFor('alice'), isTrue);
      expect(pending(requestedBy: 'alice').isIncomingFor('alice'), isFalse);
    });

    test('an accepted friendship is neither incoming nor outgoing', () {
      final accepted = Friendship(
        id: 'alice_bob',
        members: const ['alice', 'bob'],
        requestedBy: 'alice',
        status: FriendshipStatus.accepted,
        createdAt: DateTime.utc(2026, 10, 3),
        respondedAt: DateTime.utc(2026, 10, 3),
      );

      expect(accepted.isIncomingFor('bob'), isFalse);
      expect(accepted.isOutgoingFor('alice'), isFalse);
    });

    test('otherMember gives the person who is not you', () {
      expect(pending(requestedBy: 'alice').otherMember('alice'), 'bob');
      expect(pending(requestedBy: 'alice').otherMember('bob'), 'alice');
    });

    test('otherMember is empty for someone who is not involved', () {
      expect(pending(requestedBy: 'alice').otherMember('mallory'), '');
    });
  });

  group('PublicProfile', () {
    test('reads handle and photo', () {
      final profile = PublicProfile.fromMap('u1', const {
        PublicProfile.fieldUsername: 'samjones',
        PublicProfile.fieldPhotoUrl: 'https://example.test/p.jpg',
      });

      expect(profile.username, 'samjones');
      expect(profile.handle, '@samjones');
      expect(profile.photoUrl, 'https://example.test/p.jpg');
    });

    test('an empty photo url reads as no photo', () {
      // An empty string would pass a null check and then fail to load,
      // leaving a broken image where the orb should be.
      final profile = PublicProfile.fromMap('u1', const {
        PublicProfile.fieldUsername: 'samjones',
        PublicProfile.fieldPhotoUrl: '',
      });

      expect(profile.photoUrl, isNull);
    });

    test('wrong field types fall back instead of crashing', () {
      final profile = PublicProfile.fromMap('u1', const {
        PublicProfile.fieldUsername: 42,
        PublicProfile.fieldPhotoUrl: 7,
      });

      expect(profile.username, '');
      expect(profile.photoUrl, isNull);
    });

    test('the create map always carries photoUrl, even when null', () {
      // The rules list photoUrl as an allowed key, and an absent key would make
      // a later "set my photo" an add rather than a change.
      const profile = PublicProfile(
        uid: 'u1',
        username: 'samjones',
        photoUrl: null,
      );

      expect(profile.toCreateMap(), {
        PublicProfile.fieldUsername: 'samjones',
        PublicProfile.fieldPhotoUrl: null,
      });
    });
  });
}
