import 'package:aura/core/models/aura_user.dart';
import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/models/public_profile.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/features/auth/application/auth_providers.dart';
import 'package:aura/features/friends/application/friends_providers.dart';
import 'package:aura/features/friends/presentation/friends_screen.dart';
import 'package:aura/features/safety/application/safety_providers.dart';
import 'package:aura/features/settings/presentation/blocked_list_screen.dart';
import 'package:aura/features/settings/presentation/delete_account_screen.dart';
import 'package:aura/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

/// Widget tests for the slice-9 safety surfaces.
///
/// These tests were first executed locally on 2026-10-04. Some older widget
/// tests still fail in their test harness and must not be cited as passing.
///
/// What these cover, in priority order:
///
/// 1. A minor cannot switch their own leaderboard visibility on. The rules
///    enforce it; if the UI disagreed, a 16-year-old would tap a control that
///    silently failed.
/// 2. Blocking actually removes the friendship. A block that left someone on
///    your friend list would be the feature failing at its one job.
/// 3. Reporting always blocks. The rules refuse a report without one, so a UI
///    that could report alone would just produce permission errors.
/// 4. Deletion cannot fire until you have typed your own handle, and fires once.
void main() {
  late FakeAuthRepository auth;
  late FakeUserRepository users;
  late FakePublicProfileRepository profiles;
  late FakeFriendshipRepository friendships;
  late FakeSafetyRepository safety;
  late FakeAccountDeletionService deletion;

  setUp(() {
    auth = FakeAuthRepository();
    users = FakeUserRepository();
    profiles = FakePublicProfileRepository();
    friendships = FakeFriendshipRepository();
    safety = FakeSafetyRepository(friendships: friendships);
    deletion = FakeAccountDeletionService(auth: auth, users: users);
  });

  tearDown(() {
    auth.dispose();
    users.dispose();
    profiles.dispose();
    friendships.dispose();
    safety.dispose();
  });

  Future<AuraUser> signIn({
    String uid = 'me',
    String username = 'me',
    int birthYear = 2000,
    bool isMinor = false,
  }) async {
    auth.signInDirectly(uid: uid);
    final user = await users.createAccount(
      uid: uid,
      username: username,
      birthYear: birthYear,
      isMinor: isMinor,
    );
    profiles.add(PublicProfile(uid: uid, username: username, photoUrl: null));
    return user;
  }

  Widget host(Widget child) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        publicProfileRepositoryProvider.overrideWithValue(profiles),
        friendshipRepositoryProvider.overrideWithValue(friendships),
        safetyRepositoryProvider.overrideWithValue(safety),
        accountDeletionServiceProvider.overrideWithValue(deletion),
      ],
      child: MaterialApp(theme: AuraTheme.dark, home: child),
    );
  }

  group('settings', () {
    testWidgets('an adult can change who may send them aura', (tester) async {
      await signIn();
      await tester.pumpWidget(host(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('nobody'));
      await tester.pumpAndSettle();

      expect(
        users.users['me']!.privacy.whoCanSendAura,
        WhoCanSendAura.nobody,
      );
    });

    testWidgets('a minor cannot switch leaderboards on', (tester) async {
      // Locked rather than hidden: a 16-year-old should be able to see that the
      // setting exists and is off, without being able to move it.
      await signIn(birthYear: 2010, isMinor: true);
      await tester.pumpWidget(host(const SettingsScreen()));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
      expect(find.textContaining('not changeable'), findsOneWidget);
    });

    testWidgets('an adult sees the leaderboard toggle enabled', (tester) async {
      await signIn();
      await tester.pumpWidget(host(const SettingsScreen()));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(toggle.onChanged, isNotNull);
    });

    testWidgets('no notification toggles ship in this slice', (tester) async {
      // Push is slice 7 and Blaze-blocked. A dead switch teaches people the
      // settings screen lies.
      await signIn();
      await tester.pumpWidget(host(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('notification'), findsNothing);
    });
  });

  group('blocking', () {
    testWidgets('blocking a friend removes them from the list', (tester) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(
        from: 'me',
        to: 'alice',
        status: FriendshipStatus.accepted,
      );

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('@alice'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('block'));
      await tester.pumpAndSettle();
      // The confirm dialog's own 'block' button.
      await tester.tap(find.widgetWithText(TextButton, 'block'));
      await tester.pumpAndSettle();

      expect(safety.hasBlocked('me', 'alice'), isTrue);
      expect(
        friendships.byPairId[Friendship.pairIdFor('me', 'alice')],
        isNull,
      );
      expect(find.text('@alice'), findsNothing);
    });

    testWidgets('cancelling the confirm blocks nobody', (tester) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(
        from: 'me',
        to: 'alice',
        status: FriendshipStatus.accepted,
      );

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('block'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'cancel'));
      await tester.pumpAndSettle();

      expect(safety.hasBlocked('me', 'alice'), isFalse);
      expect(find.text('@alice'), findsOneWidget);
    });

    testWidgets('the blocked list unblocks', (tester) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      await safety.block(viewerUid: 'me', blockedUid: 'alice');

      await tester.pumpWidget(host(const BlockedListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('@alice'), findsOneWidget);

      await tester.tap(find.text('unblock'));
      await tester.pumpAndSettle();

      expect(safety.hasBlocked('me', 'alice'), isFalse);
    });

    testWidgets('an empty blocked list explains what blocking does', (
      tester,
    ) async {
      await signIn();
      await tester.pumpWidget(host(const BlockedListScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('nobody blocked'), findsOneWidget);
      expect(find.textContaining('are not told'), findsOneWidget);
    });
  });

  group('reporting', () {
    testWidgets('reporting files a report and blocks, together', (
      tester,
    ) async {
      // The rules refuse a report without its block, so a UI that could do one
      // without the other would only ever produce permission errors.
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(from: 'alice', to: 'me');

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('harassment'));
      await tester.pumpAndSettle();

      expect(safety.reports, ['me:alice:harassment']);
      expect(safety.hasBlocked('me', 'alice'), isTrue);
    });

    testWidgets('declining an incoming request lives in the overflow', (
      tester,
    ) async {
      // A list row fits about one button plus an overflow, so decline moved
      // into the menu beside block and report rather than squeezing the handle
      // out of its own row.
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(from: 'alice', to: 'me');

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('accept'), findsOneWidget);
      expect(find.text('decline'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('decline'));
      await tester.pumpAndSettle();

      expect(
        friendships.byPairId[Friendship.pairIdFor('me', 'alice')],
        isNull,
      );
    });

    testWidgets('the report sheet is honest about the review queue', (
      tester,
    ) async {
      await signIn();
      profiles.add(
        const PublicProfile(uid: 'alice', username: 'alice', photoUrl: null),
      );
      friendships.seed(from: 'alice', to: 'me');

      await tester.pumpWidget(host(const FriendsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('report'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not instantly'), findsOneWidget);
      expect(find.textContaining('also blocks'), findsOneWidget);
    });
  });

  group('account deletion', () {
    testWidgets('the delete button is dead until the handle is typed', (
      tester,
    ) async {
      await signIn(username: 'sam');
      await tester.pumpWidget(host(const DeleteAccountScreen()));
      await tester.pumpAndSettle();

      FilledButton deleteButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'delete my account'),
      );

      expect(deleteButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'notmyhandle');
      await tester.pumpAndSettle();
      expect(deleteButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'sam');
      await tester.pumpAndSettle();
      expect(deleteButton().onPressed, isNotNull);
    });

    testWidgets('deleting runs exactly once', (tester) async {
      await signIn(username: 'sam');
      await tester.pumpWidget(host(const DeleteAccountScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sam');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'delete my account'));
      await tester.pumpAndSettle();

      expect(deletion.deleted, ['me']);
    });

    testWidgets('says the handle is gone for good', (tester) async {
      // The part people do not expect: deleting to free up your handle for a
      // second account does not work, and they need to know beforehand.
      await signIn(username: 'sam');
      await tester.pumpWidget(host(const DeleteAccountScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('never given to anyone else'), findsOneWidget);
      expect(find.textContaining('cannot reuse it'), findsOneWidget);
    });
  });
}
