import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/models/public_profile.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/features/auth/application/auth_providers.dart';
import 'package:aura/features/auth/data/user_repository.dart';
import 'package:aura/features/friends/application/friends_providers.dart';
import 'package:aura/features/friends/presentation/add_friend_screen.dart';
import 'package:aura/features/friends/presentation/friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

/// Widget tests for the slice-2 friends screens.
///
/// ⚠️ **These have never been executed.** Windows Application Control on the
/// development machine blocks `flutter_tester.exe`, so `flutter test` cannot
/// load any test file at all — see the slice-2 task record for the exact error.
/// They are written to be correct and to run unchanged the moment that policy
/// changes or the suite moves to CI, but nothing in this file should be cited as
/// evidence that the screens work. The evidence that exists for slice 2 is the
/// 93-case Firestore rules suite (which does run) and the pure-Dart model tests
/// under `test_unit/` (which also run).
///
/// What these cover, in priority order:
///
/// 1. The consent model is visible in the UI — a request you sent shows
///    "requested", not "accept". If these ever disagreed with the security
///    rules, the app would offer a button that always failed.
/// 2. A failed lookup and a free handle look different. Conflating them sends
///    someone off to re-check a handle that was right.
/// 3. The empty state tells a first user what to do, rather than showing a void
///    to the one person guaranteed to have no friends.
void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakePublicProfileRepository profiles;
  late FakeFriendshipRepository friendships;

  setUp(() {
    auth = FakeAuthRepository();
    users = FakeUserRepository();
    profiles = FakePublicProfileRepository();
    friendships = FakeFriendshipRepository();
  });

  tearDown(() {
    auth.dispose();
    users.dispose();
    profiles.dispose();
    friendships.dispose();
  });

  /// Signs someone in and gives them an account, so the screens have a viewer.
  Future<String> signIn({String uid = 'me', String username = 'me'}) async {
    auth.signInDirectly(uid: uid);
    await users.createAccount(
      uid: uid,
      username: username,
      birthYear: 2000,
      isMinor: false,
    );
    profiles.add(
      PublicProfile(uid: uid, username: username, photoUrl: null),
    );
    return uid;
  }

  Widget host(Widget child) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        publicProfileRepositoryProvider.overrideWithValue(profiles),
        friendshipRepositoryProvider.overrideWithValue(friendships),
      ],
      child: MaterialApp(theme: AuraTheme.dark, home: child),
    );
  }

  group('friends screen', () {
    testWidgets('an empty list tells a first user what to do', (tester) async {
      await signIn(username: 'sam');
      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('no friends yet.'), findsOneWidget);
      // The handle is in the copy so the very first user has something to share
      // rather than a dead end.
      expect(find.textContaining('@sam'), findsOneWidget);
    });

    testWidgets('an incoming request is separated from an accepted friend', (
      tester,
    ) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      profiles.add(
        const PublicProfile(uid: 'bob', username: 'bob', photoUrl: null),
      );
      friendships.seed(from: 'alice', to: 'me');
      friendships.seed(
        from: 'me',
        to: 'bob',
        status: FriendshipStatus.accepted,
      );

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('waiting on you (1)'), findsOneWidget);
      expect(find.text('friends (1)'), findsOneWidget);
      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
    });

    testWidgets('a request you sent shows as sent, not as acceptable', (
      tester,
    ) async {
      // The consent model, visible. The sender must never be offered Accept.
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(from: 'me', to: 'alice');

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('sent (1)'), findsOneWidget);
      expect(find.text('requested'), findsOneWidget);
      expect(find.text('accept'), findsNothing);
    });

    testWidgets('accepting an incoming request moves it into friends', (
      tester,
    ) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(from: 'alice', to: 'me');

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('accept'));
      await tester.pumpAndSettle();

      expect(find.text('friends (1)'), findsOneWidget);
      expect(find.text('waiting on you (1)'), findsNothing);
      expect(friendships.writes, ['accept:${Friendship.pairIdFor('alice', 'me')}']);
    });
  });

  group('add a friend', () {
    testWidgets('a free handle reads as nobody having it', (tester) async {
      await signIn();
      await tester.pumpWidget(host(const AddFriendScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nobodyhome');
      await tester.tap(find.text('look up'));
      await tester.pumpAndSettle();

      expect(find.text('nobody has @nobodyhome.'), findsOneWidget);
    });

    testWidgets('a dropped connection does not read as a free handle', (
      tester,
    ) async {
      // The distinction that matters most on this screen.
      await signIn();
      profiles.failWith = AccountProblem.network;

      await tester.pumpWidget(host(const AddFriendScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'someone');
      await tester.tap(find.text('look up'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no connection'), findsOneWidget);
      expect(find.textContaining('nobody has'), findsNothing);
    });

    testWidgets('a malformed handle never reaches the backend', (tester) async {
      await signIn();
      await tester.pumpWidget(host(const AddFriendScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.text('look up'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at least'), findsOneWidget);
      expect(profiles.lookups, isEmpty);
    });

    testWidgets('searching your own handle says so', (tester) async {
      await signIn(username: 'sam');
      await tester.pumpWidget(host(const AddFriendScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sam');
      await tester.tap(find.text('look up'));
      await tester.pumpAndSettle();

      expect(find.text('that one is you.'), findsOneWidget);
    });

    testWidgets('finding someone offers an add button that writes once', (
      tester,
    ) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );

      await tester.pumpWidget(host(const AddFriendScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.tap(find.text('look up'));
      await tester.pumpAndSettle();

      expect(find.text('@alice'), findsOneWidget);
      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      expect(friendships.writes, [
        'request:${Friendship.pairIdFor('alice', 'me')}',
      ]);
      expect(find.text('requested'), findsOneWidget);
    });
  });
}
