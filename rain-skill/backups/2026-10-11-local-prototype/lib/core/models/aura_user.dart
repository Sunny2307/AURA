import '../rules/aura_rules.dart';

/// Who is allowed to send you aura (spec §5.11).
enum WhoCanSendAura {
  everyone,
  friends,
  nobody;

  /// Stored as a string rather than an index, so reordering this enum can never
  /// silently reinterpret existing documents.
  String get wireValue => name;

  static WhoCanSendAura fromWire(Object? value) {
    return switch (value) {
      'everyone' => WhoCanSendAura.everyone,
      'nobody' => WhoCanSendAura.nobody,
      // `friends` is also the fallback for an unknown or missing value: if we
      // cannot tell what someone chose, the middle setting is the one least
      // likely to surprise them in either direction.
      _ => WhoCanSendAura.friends,
    };
  }
}

/// Privacy settings. Defaults differ for minors — spec §10 requires
/// "public leaderboards off by default" for under-18s.
final class AuraPrivacy {
  const AuraPrivacy({
    required this.whoCanSendAura,
    required this.appearOnLeaderboards,
  });

  /// The defaults applied at signup. There is no single "default" constant
  /// because the correct default depends on age, and having only the age-aware
  /// factory makes it hard to accidentally give a 15-year-old adult settings.
  factory AuraPrivacy.defaultsFor({required bool isMinor}) {
    return AuraPrivacy(
      whoCanSendAura: WhoCanSendAura.friends,
      appearOnLeaderboards: !isMinor,
    );
  }

  factory AuraPrivacy.fromMap(Map<String, Object?> map) {
    return AuraPrivacy(
      whoCanSendAura: WhoCanSendAura.fromWire(map[fieldWhoCanSendAura]),
      // Defaults to false when absent. A missing field must never expose
      // someone on a leaderboard they did not opt into.
      appearOnLeaderboards: map[fieldAppearOnLeaderboards] == true,
    );
  }

  static const String fieldWhoCanSendAura = 'whoCanSendAura';
  static const String fieldAppearOnLeaderboards = 'appearOnLeaderboards';

  final WhoCanSendAura whoCanSendAura;
  final bool appearOnLeaderboards;

  Map<String, Object?> toMap() {
    return {
      fieldWhoCanSendAura: whoCanSendAura.wireValue,
      fieldAppearOnLeaderboards: appearOnLeaderboards,
    };
  }

  AuraPrivacy copyWith({
    WhoCanSendAura? whoCanSendAura,
    bool? appearOnLeaderboards,
  }) {
    return AuraPrivacy(
      whoCanSendAura: whoCanSendAura ?? this.whoCanSendAura,
      appearOnLeaderboards: appearOnLeaderboards ?? this.appearOnLeaderboards,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuraPrivacy &&
      other.whoCanSendAura == whoCanSendAura &&
      other.appearOnLeaderboards == appearOnLeaderboards;

  @override
  int get hashCode => Object.hash(whoCanSendAura, appearOnLeaderboards);
}

/// A user, as stored at `users/{uid}`.
///
/// Deliberately has **no `toMap()`**. Two reasons:
///
/// 1. The client is not allowed to write `score` — security rules reject it on
///    update (see the rules file). A general `toMap()` would include `score`,
///    so any innocent-looking "save the profile" call would be rejected
///    wholesale and the app would look broken for a reason nobody could find.
/// 2. Profile edits are narrow (photo, privacy toggles). Narrow writes are
///    also cheaper and avoid clobbering fields the client does not own, like
///    `score`.
///
/// So: [toCreateMap] for the one-time signup write, and specific repository
/// methods for everything after that.
final class AuraUser {
  const AuraUser({
    required this.uid,
    required this.username,
    required this.photoUrl,
    required this.score,
    required this.birthYear,
    required this.isMinor,
    required this.privacy,
    required this.createdAt,
  });

  /// Builds the user for a brand-new account.
  ///
  /// [isMinor] comes from [evaluateAgeGate], not from a caller's own
  /// arithmetic — that is the whole point of having the gate.
  factory AuraUser.newAccount({
    required String uid,
    required String username,
    required int birthYear,
    required bool isMinor,
    required DateTime createdAt,
    String? photoUrl,
  }) {
    return AuraUser(
      uid: uid,
      username: username,
      photoUrl: photoUrl,
      score: AuraRules.startingScore,
      birthYear: birthYear,
      isMinor: isMinor,
      privacy: AuraPrivacy.defaultsFor(isMinor: isMinor),
      createdAt: createdAt,
    );
  }

  /// Reads a document body. [uid] is passed separately because it is the
  /// document id, not a field — storing it twice invites the two to disagree.
  ///
  /// Every field is read defensively. Firestore hands back
  /// `Map<String, dynamic>` with no schema guarantee, and a document written by
  /// an older app version (or a half-finished signup) must render rather than
  /// crash the screen.
  factory AuraUser.fromMap(
    String uid,
    Map<String, Object?> map, {
    required DateTime Function(Object? value) parseTimestamp,
  }) {
    return AuraUser(
      uid: uid,
      username: switch (map[fieldUsername]) {
        final String v => v,
        _ => '',
      },
      photoUrl: switch (map[fieldPhotoUrl]) {
        final String v when v.isNotEmpty => v,
        _ => null,
      },
      // Falls back to the baseline, not 0: a user whose score field is somehow
      // missing should look neutral, not like they have been destroyed.
      score: switch (map[fieldScore]) {
        final int v => v,
        final double v => v.round(),
        _ => AuraRules.startingScore,
      },
      birthYear: switch (map[fieldBirthYear]) {
        final int v => v,
        _ => 0,
      },
      // Absent means minor. If we do not know someone's age, they get the
      // protective settings — the opposite default would quietly hand adult
      // caps to an account with corrupt data.
      isMinor: map[fieldIsMinor] != false,
      privacy: switch (map[fieldPrivacy]) {
        final Map<String, Object?> v => AuraPrivacy.fromMap(v),
        // A Firestore map arrives as Map<String, dynamic>; widen defensively in
        // case it comes through as a looser map type.
        final Map<Object?, Object?> v => AuraPrivacy.fromMap(
          v.map((key, value) => MapEntry(key.toString(), value)),
        ),
        _ => AuraPrivacy.defaultsFor(isMinor: true),
      },
      createdAt: parseTimestamp(map[fieldCreatedAt]),
    );
  }

  static const String fieldUsername = 'username';
  static const String fieldPhotoUrl = 'photoUrl';
  static const String fieldScore = 'score';
  static const String fieldBirthYear = 'birthYear';
  static const String fieldIsMinor = 'isMinor';
  static const String fieldPrivacy = 'privacy';
  static const String fieldCreatedAt = 'createdAt';

  final String uid;
  final String username;
  final String? photoUrl;
  final int score;

  // There is deliberately no `friendCount` here. It used to be a pinned-to-zero
  // field waiting for a Cloud Function to maintain it; on the Spark plan that
  // function does not exist, so the value was always 0 and nothing could legally
  // move it — a stored number that could only ever be wrong. The count is
  // derived instead, from `friendships` where this uid is an accepted member,
  // which cannot drift and cannot be inflated by a tampered client.

  final int birthYear;
  final bool isMinor;
  final AuraPrivacy privacy;
  final DateTime createdAt;

  /// The caps that apply when *this* user sends aura.
  PointCaps get pointCaps => AuraRules.pointCapsFor(isMinor: isMinor);

  /// `@username`, for display. Centralised so the `@` is never hand-typed into
  /// a string somewhere and then missed in another.
  String get handle => '@$username';

  /// The full document for the initial create.
  ///
  /// `score` is included here even though the client cannot normally write it:
  /// on create, the security rules pin it to exactly
  /// [AuraRules.startingScore], so a tampered client cannot start at a million.
  /// After creation the field is immutable to clients.
  ///
  /// `createdAt` is intentionally *not* included — the repository substitutes
  /// the server's own timestamp, because a device clock can be wrong or lied
  /// about, and this value orders things.
  Map<String, Object?> toCreateMap() {
    return {
      fieldUsername: username,
      fieldPhotoUrl: photoUrl,
      fieldScore: score,
      fieldBirthYear: birthYear,
      fieldIsMinor: isMinor,
      fieldPrivacy: privacy.toMap(),
    };
  }

  AuraUser copyWith({
    String? username,
    String? photoUrl,
    int? score,
    AuraPrivacy? privacy,
  }) {
    return AuraUser(
      uid: uid,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      score: score ?? this.score,
      birthYear: birthYear,
      isMinor: isMinor,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt,
    );
  }
}
