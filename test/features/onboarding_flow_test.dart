import 'package:aura/core/router/app_router.dart';
import 'package:aura/core/rules/aura_rules.dart';
import 'package:aura/core/theme/aura_theme.dart';
import 'package:aura/core/validation/credential_rules.dart';
import 'package:aura/core/validation/username_rules.dart';
import 'package:aura/features/auth/application/auth_providers.dart';
import 'package:aura/features/auth/data/auth_repository.dart';
import 'package:aura/features/auth/data/user_repository.dart';
import 'package:aura/features/onboarding/presentation/onboarding_screen.dart';
import 'package:aura/features/onboarding/presentation/signup_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_repositories.dart';

/// Tests for the two onboarding screens.
///
/// These are the first widget tests in the project that drive a real flow rather
/// than rendering a single component, so a note on what they are for: the point
/// is not to pin down pixels — the golden test does that — but to prove the
/// *gates* hold. A signup wizard whose age check can be walked past is worse
/// than no age check, because it looks like one.
///
/// Since Firebase landed, the signup flow also writes. Those writes go through
/// [FakeAuthRepository] and [FakeUserRepository] rather than a real backend, which
/// is what makes the failure paths testable at all: an email that is already
/// taken, a handle claimed by someone else a moment ago, a provider switched off
/// in the console. Those are the cases that actually break signups.
void main() {
  /// A plain [MaterialApp] host, for screens that do not navigate.
  ///
  /// [reduceMotion] is not a niche accessibility case here — it is how the
  /// carousel becomes testable at all. `AuraOrb` breathes on an endless
  /// `repeat(reverse: true)`, so a tree containing one *never* stops scheduling
  /// frames and [WidgetTester.pumpAndSettle] times out by design. Under
  /// reduce-motion the orb holds mid-breath, the tree quiesces, and page turns
  /// still animate because they use explicit durations.
  Widget host(Widget child, {bool reduceMotion = false}) {
    final app = MaterialApp(theme: AuraTheme.light, home: child);
    if (!reduceMotion) return app;
    return MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }

  group('onboarding carousel', () {
    testWidgets('opens on the first §7.4 headline', (tester) async {
      await tester.pumpWidget(host(const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('your friends already judge you.'), findsOneWidget);
      expect(find.text("now it's official."), findsOneWidget);
    });

    testWidgets('back is disabled on the first page and enabled after', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const OnboardingScreen(), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 50));

      TextButton backButton() => tester.widget<TextButton>(
        find.ancestor(of: find.text('back'), matching: find.byType(TextButton)),
      );

      expect(backButton().onPressed, isNull);

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();

      expect(backButton().onPressed, isNotNull);
      expect(find.text('send aura for the wins.'), findsOneWidget);
    });

    testWidgets('the last page swaps next for get started and drops skip', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const OnboardingScreen(), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('skip'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('get started'), findsOneWidget);
      expect(find.text('next'), findsNothing);
      // Still in the tree, but invisible — Visibility keeps its slot so the
      // wordmark does not jump sideways.
      final skip = tester.widget<Visibility>(
        find.ancestor(of: find.text('skip'), matching: find.byType(Visibility)),
      );
      expect(skip.visible, isFalse);
    });

    testWidgets('every page announces itself as N of 4', (tester) async {
      await tester.pumpWidget(
        host(const OnboardingScreen(), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel('page 1 of 4'), findsOneWidget);

      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('page 2 of 4'), findsOneWidget);
    });

    testWidgets('reduce motion does not break the animated art', (
      tester,
    ) async {
      // The orb art holds a Timer under normal motion. Under reduce-motion it
      // must not start one — a leaked periodic Timer fails the test framework's
      // own teardown, which is exactly the signal we want. Pumping past three
      // full 2200ms cycles would trip that if the Timer were still running.
      await tester.pumpWidget(
        host(const OnboardingScreen(), reduceMotion: true),
      );
      await tester.pump(const Duration(seconds: 7));

      expect(find.text('your friends already judge you.'), findsOneWidget);
    });
  });

  group('signup flow', () {
    late FakeAuthRepository auth;
    late FakeUserRepository users;

    setUp(() {
      auth = FakeAuthRepository();
      users = FakeUserRepository();
    });

    tearDown(() {
      auth.dispose();
      users.dispose();
    });

    /// Hosts the signup screen behind a real [GoRouter].
    ///
    /// A router is required rather than convenient: the review step finishes by
    /// calling `AppRouter.replaceWith`, which resolves `GoRouter.of(context)`. A
    /// plain `MaterialApp` would throw there, and the one assertion worth making
    /// about the last step is precisely that it lands on the home route.
    ///
    /// The home route is a marker rather than the real [HomeScreen] on purpose:
    /// that screen renders an `AuraOrb`, whose endless breath would stop the tree
    /// from ever settling. What is under test is where signup *goes*, not what is
    /// drawn when it arrives.
    Future<void> pumpSignup(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: AuraRoutes.signup,
        routes: [
          GoRoute(
            path: AuraRoutes.signup,
            builder: (context, state) => const SignupFlowScreen(),
          ),
          GoRoute(
            path: AuraRoutes.home,
            builder: (context, state) =>
                const Scaffold(body: Text('home reached')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userRepositoryProvider.overrideWithValue(users),
          ],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp.router(
              theme: AuraTheme.light,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Types [value] into the step's only field and taps continue.
    Future<void> submit(WidgetTester tester, String value) async {
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('continue'));
      await tester.pumpAndSettle();
    }

    const email = 'sam@example.com';
    // Passes [PasswordRules]: long enough, and more than two distinct characters
    // so it is not caught as tooSimple.
    const password = 'aurapass123';

    /// Walks past the credential steps. Leaves the flow on the age gate, signed
    /// in — which is the state everything after this point depends on.
    Future<void> reachBirthYear(WidgetTester tester) async {
      await pumpSignup(tester);
      await submit(tester, email);
      await submit(tester, password);
      expect(find.text('what year were you born?'), findsOneWidget);
    }

    Future<void> reachUsername(
      WidgetTester tester, {
      String year = '1998',
    }) async {
      await reachBirthYear(tester);
      await submit(tester, year);
      expect(find.text('pick your handle.'), findsOneWidget);
    }

    Future<void> reachReview(
      WidgetTester tester, {
      String year = '1998',
      String username = 'samjones',
    }) async {
      await reachUsername(tester, year: year);
      await submit(tester, username);
      expect(find.text('that is everything.'), findsOneWidget);
    }

    group('credentials', () {
      testWidgets('a malformed email does not advance', (tester) async {
        await pumpSignup(tester);

        await submit(tester, 'sam@');

        expect(find.text('that does not look like an email.'), findsOneWidget);
        expect(find.text('what is your email?'), findsOneWidget);
        // Nothing was created — the address never reached the repository.
        expect(auth.createdUids, isEmpty);
      });

      testWidgets('a short password does not advance or create an account', (
        tester,
      ) async {
        await pumpSignup(tester);
        await submit(tester, email);

        await submit(tester, 'abc');

        expect(
          find.text('at least ${PasswordRules.minLength} characters.'),
          findsOneWidget,
        );
        expect(find.text('pick a password.'), findsOneWidget);
        expect(auth.createdUids, isEmpty);
      });

      testWidgets('a password of one repeated character is refused', (
        tester,
      ) async {
        await pumpSignup(tester);
        await submit(tester, email);

        // Long enough to pass a naive length check, which is the point.
        await submit(tester, '11111111');

        expect(find.text('mix it up a bit more than that.'), findsOneWidget);
        expect(auth.createdUids, isEmpty);
      });

      testWidgets('the password step does not create an auth account yet', (
        tester,
      ) async {
        await reachBirthYear(tester);

        expect(auth.createdUids, isEmpty);
        expect(auth.currentUser, isNull);
      });

      testWidgets('an email already in use sends the user back to that step', (
        tester,
      ) async {
        auth = FakeAuthRepository(existingEmails: {email});
        await pumpSignup(tester);

        await submit(tester, email);
        await submit(tester, password);

        expect(find.text('that email already has an account.'), findsOneWidget);
        // Back on the email step, not left staring at a password field for an
        // address that was the actual mistake.
        expect(find.text('what is your email?'), findsOneWidget);
      });

      testWidgets('a disabled provider is named as a configuration fault', (
        tester,
      ) async {
        auth = FakeAuthRepository(failWith: AuthProblem.operationNotAllowed);
        await pumpSignup(tester);

        await submit(tester, email);
        await submit(tester, password);

        // Not "try again" — nothing the user does will help, and saying so
        // stops them retrying forever.
        expect(
          find.text('email sign-up is not switched on for this app yet.'),
          findsOneWidget,
        );
      });

      testWidgets('walking back over the password step creates nothing twice', (
        tester,
      ) async {
        await reachBirthYear(tester);

        await tester.tap(find.byTooltip('go back'));
        await tester.pumpAndSettle();
        expect(find.text('pick a password.'), findsOneWidget);

        await tester.tap(find.text('continue'));
        await tester.pumpAndSettle();

        expect(find.text('what year were you born?'), findsOneWidget);
        expect(auth.createdUids, isEmpty);
      });

      testWidgets('an existing auth session resumes at the age gate', (
        tester,
      ) async {
        // The app died between creating the account and writing the profile.
        auth.signInDirectly();
        await pumpSignup(tester);

        expect(find.text('what year were you born?'), findsOneWidget);
        expect(find.text('what is your email?'), findsNothing);
      });
    });

    group('age gate', () {
      testWidgets('someone under 15 is stopped and cannot continue', (
        tester,
      ) async {
        await reachBirthYear(tester);

        // Conservative arithmetic: in 2026 a 2013 birth year is treated as 12.
        await submit(tester, '2013');

        expect(
          find.text(
            'you need to be ${AuraAgeRules.minimumAge} or older to use aura.',
          ),
          findsOneWidget,
        );
        // Still on the same step — the gate is a stop, not a warning.
        expect(find.text('what year were you born?'), findsOneWidget);
        expect(find.text('pick your handle.'), findsNothing);
        expect(auth.createdUids, isEmpty);
      });

      testWidgets('a nonsense year is rejected without mentioning age', (
        tester,
      ) async {
        await reachBirthYear(tester);

        await submit(tester, '3000');

        expect(find.text('that year does not look right.'), findsOneWidget);
      });

      testWidgets('an adult year reaches the username step', (tester) async {
        await reachUsername(tester);

        expect(find.text('pick your handle.'), findsOneWidget);
      });
    });

    group('username step', () {
      testWidgets('a malformed name is rejected with actionable text', (
        tester,
      ) async {
        await reachUsername(tester);

        await submit(tester, '_nope');

        expect(find.text('start with a letter.'), findsOneWidget);
        expect(find.text('that is everything.'), findsNothing);
      });

      testWidgets('a rejected name offers tappable alternates that work', (
        tester,
      ) async {
        await reachUsername(tester);

        // Reserved, so it is rejected while still being a salvageable base.
        await tester.enterText(find.byType(TextField), 'admin');
        await tester.pumpAndSettle();

        final suggestions = UsernameRules.suggestionsFor('admin');
        expect(suggestions, isNotEmpty);
        expect(find.text('these are free:'), findsOneWidget);

        await tester.tap(find.text('@${suggestions.first}'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('continue'));
        await tester.pumpAndSettle();

        expect(find.text('@${suggestions.first}'), findsOneWidget);
        expect(find.text('that is everything.'), findsOneWidget);
      });

      testWidgets('a mixed-case name is normalised on the review step', (
        tester,
      ) async {
        await reachUsername(tester);

        await submit(tester, '  @SamJones ');

        expect(find.text('@samjones'), findsOneWidget);
      });

      testWidgets('a name held by someone else does not advance', (
        tester,
      ) async {
        users.takenUsernames.add('samjones');
        await reachUsername(tester);

        await submit(tester, 'samjones');

        expect(find.text('that one is taken. try another.'), findsOneWidget);
        expect(find.text('that is everything.'), findsNothing);
        // Alternates appear for a taken name too, not only a malformed one.
        expect(find.text('these are free:'), findsOneWidget);
      });

      testWidgets('an unreachable backend is not reported as taken', (
        tester,
      ) async {
        users.failAvailabilityWith = AccountProblem.network;
        await reachUsername(tester);

        await submit(tester, 'samjones');

        // Saying "taken" here would send someone away from a handle that is
        // actually theirs to take.
        expect(
          find.text('no connection. check your internet.'),
          findsOneWidget,
        );
        expect(find.text('that one is taken. try another.'), findsNothing);
      });
    });

    group('review step', () {
      testWidgets('an adult starts at 1000 with leaderboards on', (
        tester,
      ) async {
        await reachReview(tester);

        expect(find.text('${AuraRules.startingScore}'), findsOneWidget);
        expect(find.text('on'), findsOneWidget);
        expect(find.text('friends only'), findsOneWidget);

        final caps = AuraRules.pointCapsFor(isMinor: false);
        expect(
          find.text('${caps.maxNegative} to +${caps.maxPositive}'),
          findsOneWidget,
        );
      });

      testWidgets('a minor gets leaderboards off and the tighter range', (
        tester,
      ) async {
        // 2009 → treated as 16 in 2026: old enough to join, still a minor.
        await reachReview(tester, year: '2009');

        expect(find.text('off'), findsOneWidget);

        final caps = AuraRules.pointCapsFor(isMinor: true);
        expect(
          find.text('${caps.maxNegative} to +${caps.maxPositive}'),
          findsOneWidget,
        );
        // The tighter limits are stated, not silently applied.
        expect(find.textContaining('under 18'), findsOneWidget);
      });

      testWidgets('finishing writes the account and lands on home', (
        tester,
      ) async {
        await reachReview(tester);

        await tester.tap(find.text('finish setup'));
        await tester.pumpAndSettle();

        expect(find.text('home reached'), findsOneWidget);
        expect(auth.createdUids, hasLength(1));
        expect(users.createAttempts, ['samjones']);

        final created = users.users.values.single;
        expect(created.username, 'samjones');
        expect(created.score, AuraRules.startingScore);
        expect(created.isMinor, isFalse);
        expect(created.privacy.appearOnLeaderboards, isTrue);
      });

      testWidgets('a minor is written with protective defaults', (
        tester,
      ) async {
        await reachReview(tester, year: '2009');

        await tester.tap(find.text('finish setup'));
        await tester.pumpAndSettle();

        final created = users.users.values.single;
        expect(created.isMinor, isTrue);
        // Spec §10: public leaderboards off by default for under-18s. Asserted
        // on the written document, not on the label — the label is what the user
        // was promised, this is what was actually stored.
        expect(created.privacy.appearOnLeaderboards, isFalse);
      });

      testWidgets('losing the handle race walks back to the username step', (
        tester,
      ) async {
        await reachReview(tester);

        // Claimed by someone else between the availability read and the write.
        // Rare in practice, and exactly what the real repository's transaction
        // exists to detect rather than overwrite.
        users.takenUsernames.add('samjones');

        await tester.tap(find.text('finish setup'));
        await tester.pumpAndSettle();

        expect(
          find.text('someone just took that one. try another.'),
          findsOneWidget,
        );
        expect(find.text('pick your handle.'), findsOneWidget);
        expect(find.text('home reached'), findsNothing);
      });

      testWidgets('a rejected write keeps the user on the review step', (
        tester,
      ) async {
        users.failCreateWith = AccountProblem.permissionDenied;
        await reachReview(tester);

        await tester.tap(find.text('finish setup'));
        await tester.pumpAndSettle();

        expect(find.text('we could not save that. try again.'), findsOneWidget);
        // No navigation on failure. Landing on home with no document would
        // render an account that does not exist.
        expect(find.text('home reached'), findsNothing);
        expect(users.users, isEmpty);
      });
    });
  });
}
