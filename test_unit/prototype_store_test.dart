import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import 'package:aura/prototype/prototype_store.dart';
import 'package:aura/core/models/aura_user.dart';
import 'package:aura/core/models/friendship.dart';

void main() {
  late PrototypeStore store;
  late String saved;
  setUp(() {
    saved = '';
    store = PrototypeStore(
      save: (v) async {
        saved = v;
      },
    );
  });
  tearDown(() => store.dispose());

  Future<void> send({
    int points = 80,
    String key = 'key',
    String reason = 'had my back',
  }) => store.send(
    recipient: 'sample-sam',
    points: points,
    reason: reason,
    visibility: 'friends',
    key: key,
  );

  test(
    'demo has accepted friends, incoming request and searchable stranger',
    () async {
      await store.openDemo();
      expect(
        store.friends(store.currentUid!, FriendshipStatus.accepted),
        hasLength(2),
      );
      expect(
        store
            .friends(store.currentUid!, FriendshipStatus.pending)
            .single
            .isIncomingFor(store.currentUid!),
        isTrue,
      );
      expect(store.find('jordan')?.uid, 'sample-jordan');
    },
  );
  test('saved session, scores and history survive reload', () async {
    await store.openDemo();
    await send();
    final restored = PrototypeStore(restored: saved, save: (_) async {});
    addTearDown(restored.dispose);
    expect(restored.currentUid, store.currentUid);
    expect(restored.user('sample-sam')!.score, 1080);
    expect(restored.user(store.currentUid!)!.score, 1000);
    expect(restored.history, hasLength(1));
  });
  test('send replay is exactly once; changed replay rejected', () async {
    await store.openDemo();
    await send();
    await send();
    expect(store.user('sample-sam')!.score, 1080);
    await expectLater(send(points: 81), throwsA(isA<PrototypeFailure>()));
  });
  test('caps, non-friends and negative rolling limit are enforced', () async {
    await store.openDemo();
    await expectLater(send(points: -301), throwsA(isA<PrototypeFailure>()));
    await expectLater(
      store.send(
        recipient: 'sample-jordan',
        points: 10,
        reason: 'hello',
        visibility: 'private',
        key: 'stranger',
      ),
      throwsA(isA<PrototypeFailure>()),
    );
    for (var i = 0; i < 5; i++) {
      await send(points: -10, key: '$i');
    }
    await expectLater(
      send(points: -10, key: 'six'),
      throwsA(isA<PrototypeFailure>()),
    );
    expect(store.user('sample-sam')!.score, 950);
  });
  test('incoming accept, outgoing cancellation, other-side acceptance and unfriend', () async {
    await store.openDemo();
    final me = store.currentUid!;
    await store.accept(me, 'sample-alex');
    expect(
      store.friendship(me, 'sample-alex')!.status,
      FriendshipStatus.accepted,
    );
    await store.request(me, 'sample-jordan');
    await expectLater(
      store.accept(me, 'sample-jordan'),
      throwsA(isA<PrototypeFailure>()),
    );
    await store.remove(me, 'sample-jordan');
    expect(store.friendship(me, 'sample-jordan'), isNull);
    await store.request(me, 'sample-jordan');
    await store.resume('sample-jordan');
    await store.accept('sample-jordan', me);
    await store.remove('sample-jordan', me);
    expect(store.friendship(me, 'sample-jordan'), isNull);
  });
  test(
    'report blocks and removes friendship; unblock does not restore it',
    () async {
      await store.openDemo();
      final me = store.currentUid!;
      await store.report(me, 'sample-sam', 'harassment');
      expect(store.blocked(me), contains('sample-sam'));
      expect(store.friendship(me, 'sample-sam'), isNull);
      expect(
        (jsonDecode(saved) as Map<String, dynamic>)['reports'],
        hasLength(1),
      );
      await expectLater(send(), throwsA(isA<PrototypeFailure>()));
      await store.unblock(me, 'sample-sam');
      expect(store.blocked(me), isEmpty);
      expect(store.friendship(me, 'sample-sam'), isNull);
    },
  );
  test('privacy mutations persist and gate sends', () async {
    await store.openDemo();
    final me = store.currentUid!;
    await store.resume('sample-sam');
    await store.privacy(
      'sample-sam',
      const AuraPrivacy(
        whoCanSendAura: WhoCanSendAura.nobody,
        appearOnLeaderboards: false,
      ),
    );
    await store.resume(me);
    await expectLater(send(), throwsA(isA<PrototypeFailure>()));
    final restored = PrototypeStore(restored: saved, save: (_) async {});
    addTearDown(restored.dispose);
    expect(
      restored.user('sample-sam')!.privacy.whoCanSendAura,
      WhoCanSendAura.nobody,
    );
  });
  test(
    'signup reserves handle, minor privacy cannot enable leaderboard',
    () async {
      final uid = await store.signUp('prototype@example.test');
      final year = DateTime.now().year - 17;
      await store.createAccount(uid, 'test_person', year, true);
      expect(store.available('test_person'), isFalse);
      await expectLater(
        store.privacy(
          uid,
          const AuraPrivacy(
            whoCanSendAura: WhoCanSendAura.friends,
            appearOnLeaderboards: true,
          ),
        ),
        throwsA(isA<PrototypeFailure>()),
      );
      await expectLater(
        store.createAccount(uid, 'another_name', year, true),
        throwsA(isA<PrototypeFailure>()),
      );
      expect(saved, isNot(contains('password')));
    },
  );
  test(
    'photo is visible in both profile views after reload and can be cleared',
    () async {
      await store.openDemo();
      final me = store.currentUid!;
      await store.photo(me, 'file:///prototype/photo.jpg');
      final restored = PrototypeStore(restored: saved, save: (_) async {});
      addTearDown(restored.dispose);
      expect(restored.user(me)!.photoUrl, restored.profile(me)!.photoUrl);
      await store.photo(me, null);
      expect(store.profile(me)!.photoUrl, isNull);
    },
  );
  test(
    'deletion purges personal state and retains username tombstone',
    () async {
      await store.openDemo();
      final me = store.currentUid!;
      await send();
      await store.deleteAccount(me);
      expect(store.currentUid, isNull);
      expect(store.user(me), isNull);
      expect(store.available('aura_demo'), isFalse);
      final restored = PrototypeStore(restored: saved, save: (_) async {});
      addTearDown(restored.dispose);
      expect(restored.accounts.any((a) => a.uid == me), isFalse);
      expect(
        restored.friends('sample-sam', FriendshipStatus.accepted),
        isEmpty,
      );
      await store.openDemo();
      expect(store.currentUid, isNot(me));
      expect(store.user(store.currentUid!)!.username, isNot('aura_demo'));
    },
  );
  test('reset restores clean demo data and signs out', () async {
    await store.openDemo();
    await send();
    await store.reset();
    expect(store.currentUid, isNull);
    expect(store.available('aura_demo'), isTrue);
    expect(store.user('sample-sam')!.score, 1000);
    await store.openDemo();
    expect(store.history, isEmpty);
  });
  test(
    'failed save rolls back changes; next action can still succeed',
    () async {
      var fail = false;
      final local = PrototypeStore(
        save: (_) async {
          if (fail) throw StateError('disk full');
        },
      );
      addTearDown(local.dispose);
      await local.openDemo();
      fail = true;
      await expectLater(
        local.block(local.currentUid!, 'sample-sam'),
        throwsStateError,
      );
      expect(local.blocked(local.currentUid!), isEmpty);
      expect(local.friendship(local.currentUid!, 'sample-sam'), isNotNull);
      fail = false;
      await local.block(local.currentUid!, 'sample-sam');
      expect(local.blocked(local.currentUid!), contains('sample-sam'));
    },
  );
  test(
    'concurrent sends are serialized and neither score update is lost',
    () async {
      await store.openDemo();
      await Future.wait([send(key: 'a'), send(key: 'b')]);
      expect(store.user('sample-sam')!.score, 1160);
    },
  );
  test('watchers see initial state and committed mutations', () async {
    await store.openDemo();
    final received = <int>[];
    final sub = store
        .watch(() => store.user('sample-sam')!.score)
        .listen(received.add);
    await Future<void>.delayed(Duration.zero);
    await send();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(received, [1000, 1080]);
  });
  test('deleted sample is not silently recreated on restart', () async {
    await store.resume('sample-sam');
    await store.deleteAccount('sample-sam');
    final restored = PrototypeStore(restored: saved, save: (_) async {});
    addTearDown(restored.dispose);
    expect(restored.user('sample-sam'), isNull);
    await restored.openDemo();
    expect(
      restored
          .friends(restored.currentUid!, FriendshipStatus.accepted)
          .any((f) => f.members.contains('sample-sam')),
      isFalse,
    );
  });
  test(
    'malformed saved data fails explicitly rather than discarding progress',
    () {
      expect(
        () => PrototypeStore(restored: '{}', save: (_) async {}),
        throwsFormatException,
      );
    },
  );
}
