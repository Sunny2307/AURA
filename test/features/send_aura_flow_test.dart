import 'package:aura/core/models/friendship.dart';
import 'package:aura/core/models/public_profile.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/features/auth/application/auth_providers.dart';
import 'package:aura/features/friends/application/friends_providers.dart';
import 'package:aura/features/send/data/aura_api.dart';
import 'package:aura/features/send/presentation/send_aura_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

final class _FakeAuraApi implements AuraApi {
  String? recipient;
  int? points;
  String? reason;

  @override
  Future<void> purgeForDeletion() async {}

  @override
  Future<void> send({
    required String recipientUid,
    required int points,
    required String reason,
    required String visibility,
    required String idempotencyKey,
    String? chipId,
  }) async {
    recipient = recipientUid;
    this.points = points;
    this.reason = reason;
  }
}

void main() {
  testWidgets('send requires a selected friend and reason', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = FakeAuthRepository()..signInDirectly(uid: 'me');
    final users = FakeUserRepository();
    final profiles = FakePublicProfileRepository();
    final friendships = FakeFriendshipRepository();
    final api = _FakeAuraApi();
    addTearDown(() {
      auth.dispose();
      users.dispose();
      profiles.dispose();
      friendships.dispose();
    });
    await users.createAccount(
      uid: 'me', username: 'me_user', birthYear: 2000, isMinor: false,
    );
    profiles.add(const PublicProfile(uid: 'bob', username: 'bob', photoUrl: null));
    friendships.seed(from: 'me', to: 'bob', status: FriendshipStatus.accepted);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        publicProfileRepositoryProvider.overrideWithValue(profiles),
        friendshipRepositoryProvider.overrideWithValue(friendships),
        auraApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: AuraTheme.light, home: const SendAuraScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'send aura')).onPressed, isNull);
    await tester.tap(find.text('@bob'));
    await tester.tap(find.text('showed up for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'send aura'));
    await tester.pumpAndSettle();
    expect(api.recipient, 'bob');
    expect(api.points, 80);
    expect(api.reason, 'showed up for me');
  });
}
