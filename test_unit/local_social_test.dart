import 'dart:convert';

import 'package:test/test.dart';
import 'package:aura/prototype/prototype_store.dart';

void main() {
  late PrototypeStore store;
  late String saved;
  setUp(() async {
    saved = '';
    store = PrototypeStore(save: (v) async => saved = v);
    await store.openDemo();
  });
  tearDown(() async => store.dispose());
  Future<void> send({String visibility = 'friends'}) => store.send(
    recipient: 'sample-sam',
    points: 80,
    reason: 'clutch save',
    visibility: visibility,
    key: 'one',
  );
  test('feed, score, reaction, activity and bio survive restart', () async {
    final me = store.currentUid!;
    await send();
    final id = store.feed.single.id;
    await store.react(id, '🔥');
    await store.editBio(me, 'good energy only');
    await store.resume('sample-sam');
    expect(store.user('sample-sam')!.score, 1080);
    expect(store.activity.length, 2);
    await store.markRead(store.activity.first.id);
    final restored = PrototypeStore(restored: saved, save: (_) async {});
    addTearDown(restored.dispose);
    expect(restored.feed.single.reactions[me], '🔥');
    expect(restored.bio(me), 'good energy only');
    expect(restored.activity.first.read, isTrue);
    expect(restored.rank, 1);
  });
  test('private moments hidden from friends; blocks remove access', () async {
    final me = store.currentUid!;
    await send(visibility: 'private');
    final id = store.feed.single.id;
    await store.resume('sample-maya');
    expect(store.moment(id), isNull);
    await expectLater(store.react(id, '🔥'), throwsA(isA<PrototypeFailure>()));
    await store.resume(me);
    await store.block(me, 'sample-sam');
    expect(store.moment(id), isNull);
    expect(store.canViewProfile('sample-sam'), isFalse);
    expect(store.leaderboard.any((u) => u.uid == 'sample-sam'), isFalse);
  });
  test(
    'blocking a third-party reactor hides activity and reaction counts',
    () async {
      final me = store.currentUid!;
      await send();
      final id = store.feed.single.id;
      await store.resume('sample-maya');
      await store.request('sample-maya', 'sample-sam');
      await store.resume('sample-sam');
      await store.accept('sample-sam', 'sample-maya');
      await store.resume('sample-maya');
      await store.react(id, '🔥');
      await store.resume(me);
      expect(store.activity.any((e) => e.actor == 'sample-maya'), isTrue);
      await store.block(me, 'sample-maya');
      expect(store.moment(id), isNotNull);
      expect(store.activity.any((e) => e.actor == 'sample-maya'), isFalse);
      expect(store.moment(id)!.reactions.containsKey('sample-maya'), isFalse);
      await store.react(id, '👑');
      await store.resume('sample-sam');
      expect(store.moment(id)!.reactions['sample-maya'], '🔥');
    },
  );
  test(
    'friends moment requires viewer accepted by both participants',
    () async {
      final me = store.currentUid!;
      await send();
      final id = store.feed.single.id;
      await store.resume('sample-maya');
      expect(store.moment(id), isNull);
      await store.request('sample-maya', 'sample-sam');
      await store.resume('sample-sam');
      await store.accept('sample-sam', 'sample-maya');
      await store.resume('sample-maya');
      expect(store.moment(id), isNotNull);
      await store.remove('sample-maya', me);
      expect(store.moment(id), isNull);
    },
  );
  test(
    'reactions toggle and notification preference suppresses new events',
    () async {
      final me = store.currentUid!;
      await store.resume('sample-sam');
      await store.setPreference('transactions', false);
      await store.setPreference('reactions', false);
      await store.resume(me);
      await send();
      final id = store.feed.single.id;
      await store.react(id, '👑');
      await store.react(id, '👑');
      expect(store.feed.single.reactions, isEmpty);
      await store.resume('sample-sam');
      expect(store.activity, isEmpty);
    },
  );
  test(
    'v1 saved state without new fields migrates without dropping accounts',
    () async {
      await send();
      final old = jsonDecode(saved) as Map<String, dynamic>;
      old.remove('details');
      old.remove('activity');
      old.remove('preferences');
      final restored = PrototypeStore(
        restored: jsonEncode(old),
        save: (_) async {},
      );
      addTearDown(restored.dispose);
      expect(restored.feed.single.points, 80);
      expect(restored.accounts.length, store.accounts.length);
      expect(restored.bio(restored.currentUid!), '');
      await restored.react(restored.feed.single.id, '🔥');
    },
  );
  test('sample seeding is idempotent; ranking and history agree', () async {
    await store.seedMoments();
    final score = store.user(store.currentUid!)!.score;
    await store.seedMoments();
    expect(store.feed.length, 8);
    expect(store.user(store.currentUid!)!.score, score);
    expect(store.rank, 1);
    expect(store.scoreHistory(store.currentUid!).last, score);
    expect(store.scoreHistory(store.currentUid!).first, 1000);
  });
  test('deletion cleans personal metadata, reactions and activity', () async {
    final me = store.currentUid!;
    await send();
    await store.react(store.feed.single.id, '😭');
    await store.editBio(me, 'hello');
    await store.deleteAccount(me);
    final data = jsonDecode(saved) as Map<String, dynamic>;
    expect((data['details'] as Map).containsKey(me), isFalse);
    expect(data['activity'], isEmpty);
    expect(store.available('aura_demo'), isFalse);
  });
  test('failed social save rolls back and later mutation succeeds', () async {
    var fail = false;
    final local = PrototypeStore(
      save: (_) async {
        if (fail) throw StateError('disk');
      },
    );
    addTearDown(local.dispose);
    await local.openDemo();
    await local.seedMoments();
    final id = local.feed.first.id;
    fail = true;
    await expectLater(local.react(id, '🔥'), throwsStateError);
    expect(local.moment(id)!.reactions, isEmpty);
    fail = false;
    await local.react(id, '🔥');
    expect(local.moment(id)!.reactions[local.currentUid], '🔥');
  });
}
