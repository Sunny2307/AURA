/// Email and password rules for signup.
///
/// **Context worth knowing:** the spec (§5.3) asks for phone + OTP, not email.
/// Email/password is a deliberate beta substitution — phone OTP bills per SMS and
/// so needs the paid Blaze plan, which this project is not on yet. Recorded in
/// `aura-mvp-plan.md` along with what it costs (contact-based friend matching in
/// slice 2 has no phone number to hash).
///
/// Both checks below are for *feedback*, not enforcement. Firebase Auth is the
/// authority on whether an email is usable and a password acceptable; these exist
/// so someone typing `sam@` is told immediately rather than after a round trip.
library;

/// Why an email was rejected.
enum EmailProblem { empty, malformed }

/// Why a password was rejected.
enum PasswordProblem {
  empty,
  tooShort,

  /// All one character class — `aaaaaaaa`, `12345678`. Long enough for Firebase,
  /// trivially guessable in practice.
  tooSimple,
}

abstract final class EmailRules {
  /// Deliberately loose.
  ///
  /// There is no correct email regex — RFC 5322 addresses can contain quoted
  /// strings, comments and IP literals, and every "strict" pattern in circulation
  /// rejects real addresses. So this checks the only three things whose absence
  /// is *always* wrong: something before an `@`, something after it, and a dot in
  /// the domain. Everything past that is Firebase's call, and ultimately the
  /// inbox's.
  static final RegExp _shape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String normalise(String raw) => raw.trim();

  static EmailProblem? check(String raw) {
    final value = normalise(raw);
    if (value.isEmpty) return EmailProblem.empty;
    if (!_shape.hasMatch(value)) return EmailProblem.malformed;
    return null;
  }
}

abstract final class PasswordRules {
  /// Firebase's own floor is 6. Eight is the floor here.
  ///
  /// The two extra characters cost a beta user almost nothing, and this is an app
  /// where an account takeover means posting judgments in someone's name to their
  /// own friend group. Set above the platform minimum on purpose so raising it
  /// later does not require a Firebase policy change too.
  static const int minLength = 8;

  /// No maximum, and no trimming.
  ///
  /// Trimming a password would silently change what someone typed and make their
  /// own password fail on a different client that did not trim. Whitespace is a
  /// legitimate password character.
  static PasswordProblem? check(String raw) {
    if (raw.isEmpty) return PasswordProblem.empty;
    if (raw.length < minLength) return PasswordProblem.tooShort;

    // A single repeated character, or pure digits/pure letters at exactly the
    // minimum length. Not a strength meter — the goal is to catch `password`
    // and `11111111`, not to demand a symbol, which mostly produces
    // `Password1!` and a sticky note.
    final distinct = raw.split('').toSet().length;
    if (distinct <= 2) return PasswordProblem.tooSimple;

    return null;
  }
}
