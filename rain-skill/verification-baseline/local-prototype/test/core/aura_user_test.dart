import 'package:aura/core/models/aura_user.dart';
import 'package:aura/core/rules/aura_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for the Firestore `Timestamp` conversion the repository injects.
/// Kept dumb on purpose: these tests are about the model, not about Firestore.
DateTime parseEpochMillis(Object? value) {
  return switch (value) {
    final int v => DateTime.fromMillisecondsSinceEpoch(v, isUtc: true),
    _ => DateTime.utc(1970),
  };
}

void main() {
  group('new account', () {
    test('starts at the baseline score with no friends', () {
      final user = AuraUser.newAccount(
        uid: 'u1',
        username: 'sam',
        birthYear: 2000,
        isMinor: false,
        createdAt: DateTime.utc(2026, 9, 4),
      );

      expect(user.score, AuraRules.startingScore);
      expect(user.photoUrl, isNull);
    });

    test('an adult appears on leaderboards by default', () {
      final user = AuraUser.newAccount(
        uid: 'u1',
        username: 'sam',
        birthYear: 2000,
        isMinor: false,
        createdAt: DateTime.utc(2026),
      );
      expect(user.privacy.appearOnLeaderboards, isTrue);
    });

    test('a minor does not, per spec 10', () {
      final user = AuraUser.newAccount(
        uid: 'u2',
        username: 'kid',
        birthYear: 2010,
        isMinor: true,
        createdAt: DateTime.utc(2026),
      );
      expect(user.privacy.appearOnLeaderboards, isFalse);
    });

    test('both ages default to friends-only sending', () {
      for (final isMinor in [true, false]) {
        final user = AuraUser.newAccount(
          uid: 'u',
          username: 'sam',
          birthYear: 2005,
          isMinor: isMinor,
          createdAt: DateTime.utc(2026),
        );
        expect(user.privacy.whoCanSendAura, WhoCanSendAura.friends);
      }
    });

    test('point caps follow the minor flag', () {
      final minor = AuraUser.newAccount(
        uid: 'u',
        username: 'a',
        birthYear: 2010,
        isMinor: true,
        createdAt: DateTime.utc(2026),
      );
      final adult = minor.copyWith();

      expect(minor.pointCaps.maxPositive, 300);
      // copyWith cannot change isMinor, so the caps must be unchanged too.
      expect(adult.pointCaps.maxPositive, 300);
    });
  });

  group('create payload', () {
    final user = AuraUser.newAccount(
      uid: 'u1',
      username: 'sam',
      birthYear: 2000,
      isMinor: false,
      createdAt: DateTime.utc(2026, 9, 4),
    );

    test('omits createdAt so the server stamps it', () {
      // A device clock can be wrong or deliberately set, and this value orders
      // the feed. It must come from the server.
      expect(user.toCreateMap().containsKey(AuraUser.fieldCreatedAt), isFalse);
    });

    test('omits the uid, which is the document id not a field', () {
      expect(user.toCreateMap().containsKey('uid'), isFalse);
    });

    test('pins the score to the baseline for the rules to check', () {
      expect(user.toCreateMap()[AuraUser.fieldScore], AuraRules.startingScore);
    });

    test('carries the privacy block as a nested map', () {
      final privacy = user.toCreateMap()[AuraUser.fieldPrivacy];
      expect(privacy, isA<Map<String, Object?>>());
      expect(
        (privacy! as Map<String, Object?>)[AuraPrivacy.fieldWhoCanSendAura],
        'friends',
      );
    });
  });

  group('reading a document defensively', () {
    test('an empty document does not throw', () {
      final user = AuraUser.fromMap(
        'u1',
        const {},
        parseTimestamp: parseEpochMillis,
      );

      expect(user.uid, 'u1');
      expect(user.username, '');
      expect(user.photoUrl, isNull);
    });

    test('a missing score reads as neutral, not as zero', () {
      // Zero would render as a destroyed account on the home screen, which is
      // a far worse thing to show someone than a neutral 1000.
      final user = AuraUser.fromMap(
        'u1',
        const {},
        parseTimestamp: parseEpochMillis,
      );
      expect(user.score, AuraRules.startingScore);
    });

    test('a missing isMinor reads as minor, the protective default', () {
      final user = AuraUser.fromMap(
        'u1',
        const {},
        parseTimestamp: parseEpochMillis,
      );
      expect(user.isMinor, isTrue);
      expect(user.pointCaps.maxPositive, 300);
    });

    test('a missing privacy block does not expose anyone on a leaderboard', () {
      final user = AuraUser.fromMap(
        'u1',
        const {},
        parseTimestamp: parseEpochMillis,
      );
      expect(user.privacy.appearOnLeaderboards, isFalse);
    });

    test('a score stored as a double is rounded, not dropped', () {
      // Firestore has one number type and a Cloud Function increment can come
      // back as a double. Dropping it would show a wrong score.
      final user = AuraUser.fromMap(
        'u1',
        const {AuraUser.fieldScore: 1080.0},
        parseTimestamp: parseEpochMillis,
      );
      expect(user.score, 1080);
    });

    test('an empty photoUrl string reads as no photo', () {
      final user = AuraUser.fromMap(
        'u1',
        const {AuraUser.fieldPhotoUrl: ''},
        parseTimestamp: parseEpochMillis,
      );
      expect(user.photoUrl, isNull);
    });

    test('wrong field types fall back instead of crashing the screen', () {
      final user = AuraUser.fromMap(
        'u1',
        const {
          AuraUser.fieldUsername: 42,
          AuraUser.fieldScore: 'lots',
          AuraUser.fieldPrivacy: 'nope',
        },
        parseTimestamp: parseEpochMillis,
      );

      expect(user.username, '');
      expect(user.score, AuraRules.startingScore);
      expect(user.privacy.appearOnLeaderboards, isFalse);
    });

    test('a full document round-trips its real values', () {
      final user = AuraUser.fromMap(
        'u1',
        const {
          AuraUser.fieldUsername: 'sam',
          AuraUser.fieldPhotoUrl: 'https://example.test/p.jpg',
          AuraUser.fieldScore: 1420,
          AuraUser.fieldBirthYear: 2004,
          AuraUser.fieldIsMinor: false,
          AuraUser.fieldPrivacy: {
            AuraPrivacy.fieldWhoCanSendAura: 'everyone',
            AuraPrivacy.fieldAppearOnLeaderboards: true,
          },
          AuraUser.fieldCreatedAt: 1756900000000,
        },
        parseTimestamp: parseEpochMillis,
      );

      expect(user.username, 'sam');
      expect(user.handle, '@sam');
      expect(user.photoUrl, 'https://example.test/p.jpg');
      expect(user.score, 1420);
      expect(user.birthYear, 2004);
      expect(user.isMinor, isFalse);
      expect(user.privacy.whoCanSendAura, WhoCanSendAura.everyone);
      expect(user.privacy.appearOnLeaderboards, isTrue);
      expect(user.pointCaps.maxPositive, 500);
    });
  });

  group('privacy wire format', () {
    test('is stored as a name, so reordering the enum is safe', () {
      expect(WhoCanSendAura.everyone.wireValue, 'everyone');
      expect(WhoCanSendAura.friends.wireValue, 'friends');
      expect(WhoCanSendAura.nobody.wireValue, 'nobody');
    });

    test('round-trips every value', () {
      for (final value in WhoCanSendAura.values) {
        expect(WhoCanSendAura.fromWire(value.wireValue), value);
      }
    });

    test('an unknown or missing value falls back to friends', () {
      expect(WhoCanSendAura.fromWire('mutuals'), WhoCanSendAura.friends);
      expect(WhoCanSendAura.fromWire(null), WhoCanSendAura.friends);
      expect(WhoCanSendAura.fromWire(7), WhoCanSendAura.friends);
    });

    test('equality is by value, so state comparisons work', () {
      expect(
        AuraPrivacy.defaultsFor(isMinor: true),
        AuraPrivacy.defaultsFor(isMinor: true),
      );
      expect(
        AuraPrivacy.defaultsFor(isMinor: true),
        isNot(AuraPrivacy.defaultsFor(isMinor: false)),
      );
    });
  });

  test('copyWith cannot change age or identity fields', () {
    // These are set once at signup. If copyWith could change them, a settings
    // screen could quietly turn a minor into an adult and lift their caps.
    final user = AuraUser.newAccount(
      uid: 'u1',
      username: 'sam',
      birthYear: 2010,
      isMinor: true,
      createdAt: DateTime.utc(2026),
    );

    final edited = user.copyWith(username: 'samuel', score: 2000);

    expect(edited.uid, 'u1');
    expect(edited.birthYear, 2010);
    expect(edited.isMinor, isTrue);
    expect(edited.createdAt, user.createdAt);
    expect(edited.username, 'samuel');
  });
}
