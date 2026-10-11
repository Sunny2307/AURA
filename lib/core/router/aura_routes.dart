/// Route paths and the invite-link format.
///
/// Deliberately in its own file with **no Flutter imports**. `app_router.dart`
/// pulls in every screen, and therefore `dart:ui`, which means anything that
/// imports it cannot be loaded by the plain Dart VM. These constants need to be
/// testable: `flutter test` cannot run on the development machine at all
/// (Windows Application Control blocks `flutter_tester.exe`), so the only tests
/// that actually execute are the Flutter-free ones under `test_unit/`.
///
/// `app_router.dart` re-exports this file, so existing imports keep working.
library;

/// App routes.
///
/// There is deliberately **no GoRouter `redirect` guard**, even though auth state
/// is now real. The splash screen branches on `SignupStatus` instead, and this is
/// a considered choice rather than an omission:
///
/// A global redirect that sends every signed-out user to onboarding would fight
/// the signup flow, which is *signed in* from its password step onward and must
/// stay put while the profile document does not exist yet. Encoding "signed in
/// but mid-signup is allowed on /signup, and only there" as a redirect predicate
/// means the router has to know the flow's internals. One branch on one screen is
/// smaller and easier to be sure about.
///
/// When slice 2 adds screens that genuinely must not be reached without an
/// account, the guard to add is per-route, not global.
abstract final class AuraRoutes {
  static const onboarding = '/';
  static const signup = '/signup';
  static const splash = '/splash';
  static const home = '/home';
  static const sendAura = '/send';
  static const photo = '/profile/photo';
  static const designCheck = '/_design';

  /// Slice 2.
  static const friends = '/friends';
  static const addFriend = '/friends/add';

  /// Where an invite link lands. `:username` rather than a uid because the link
  /// is read by humans before it is read by the app.
  static const profileByUsername = '/u/:username';

  /// Slice 9.
  static const settings = '/settings';
  static const blockedList = '/settings/blocked';
  static const deleteAccount = '/settings/delete';

  /// The custom scheme in a shared invite link, as registered in the Android
  /// manifest. A plain `https://` link would be better — it would survive the
  /// app not being installed — but that needs a registered domain to host the
  /// `assetlinks.json`, which this project does not have yet.
  static const inviteScheme = 'aura';

  static String profileFor(String username) => '/u/$username';

  /// The shareable invite link.
  ///
  /// **Note the three slashes.** `aura://u/sam` looks right and is wrong: in URI
  /// syntax the `u` is the *authority*, so the path is `/sam`, and go_router
  /// matches on path alone — the link would resolve to the route `/sam` and dead
  /// end at the error page. Worse, `aura://anything/_design` would have reached
  /// the dev screen the same way.
  ///
  /// `aura:///u/sam` has an empty authority, so the path is `/u/sam` and it
  /// matches [profileByUsername] as intended. `test_unit/invite_link_test.dart`
  /// pins this, because it is the kind of thing that looks correct in review and
  /// is only falsified by parsing it.
  static String inviteLinkFor(String username) =>
      '$inviteScheme:///u/$username';
}
