/// Pins the invite link's URI shape.
///
/// This test exists because the first version of the feature was wrong in a way
/// that reads as correct: the link was `aura://u/<handle>`, which *looks* like
/// the path `/u/<handle>` and is not. In URI syntax the `u` is the authority, so
/// the path is just `/<handle>` — and go_router matches on path alone. Every
/// shared link would have dead-ended at the error page, and
/// `aura://anything/_design` would have opened the developer screen from outside
/// the app.
///
/// Nothing about that is visible by reading the code. It is only visible by
/// parsing the string, which is what this file does.
///
/// Runs under `dart test test_unit` — no Flutter binding needed, which matters
/// because `flutter test` cannot run on this machine at all.
library;

// The constants file directly, not `app_router.dart` — that one imports every
// screen and therefore dart:ui, which the plain Dart VM cannot load.
import 'package:aura/core/router/aura_routes.dart';
import 'package:test/test.dart';

void main() {
  group('invite link', () {
    test('parses to the path the router actually matches', () {
      final uri = Uri.parse(AuraRoutes.inviteLinkFor('samjones'));

      expect(uri.scheme, AuraRoutes.inviteScheme);
      // The empty authority is the whole point.
      expect(uri.host, isEmpty);
      expect(uri.path, '/u/samjones');
    });

    test('its path matches the declared route pattern', () {
      final uri = Uri.parse(AuraRoutes.inviteLinkFor('samjones'));
      final pattern = AuraRoutes.profileByUsername.replaceAll(
        ':username',
        'samjones',
      );

      expect(uri.path, pattern);
      expect(uri.path, AuraRoutes.profileFor('samjones'));
    });

    test('the two-slash form does NOT give the path, which is why it is unused', () {
      // Kept as a live assertion rather than a comment, so that anyone
      // "simplifying" inviteLinkFor back to two slashes gets a failure instead
      // of a silently broken feature.
      final wrong = Uri.parse('${AuraRoutes.inviteScheme}://u/samjones');

      expect(wrong.host, 'u');
      expect(wrong.path, '/samjones');
      expect(wrong.path, isNot('/u/samjones'));
    });

    test('a two-slash link would have reached the dev route', () {
      // The reason /_design is now compiled out of release builds.
      final hostile = Uri.parse('${AuraRoutes.inviteScheme}://x/_design');

      expect(hostile.path, AuraRoutes.designCheck);
    });
  });
}
