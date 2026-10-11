/// Username rules and normalisation.
///
/// The spec (§5.3) only says "username selection (real-time availability check,
/// suggest alternates if taken)", so the character rules below are a design
/// decision made here. The reasoning, since it is not in the spec:
///
/// * **Lowercase only, stored lowercase.** Firestore has no case-insensitive
///   index. If `Sam` and `sam` were both storable, they would be different
///   documents and two people would look identical in a feed. Normalising on
///   the way in is far simpler than a second lowercase mirror field.
/// * **`a-z 0-9 _` only.** No unicode, so no homoglyph impersonation — `pаul`
///   with a Cyrillic а cannot be registered to shadow `paul`. On an app whose
///   entire premise is attributing judgment to a named person, being sure who
///   you are looking at is a safety property, not a nicety.
/// * **Must start with a letter.** Keeps handles from colliding with anything
///   numeric (ids, scores) and reads better after the `@`.
library;

/// Why a username was rejected. Separate cases rather than a message string so
/// the UI owns the copy and can write it in the app's voice.
enum UsernameProblem {
  empty,
  tooShort,
  tooLong,
  badCharacters,
  mustStartWithLetter,
  doubleUnderscore,
  trailingUnderscore,
  reserved,
}

/// The result of validating a *candidate* username. Availability is a separate
/// question answered by the server — this only covers what can be decided
/// offline, instantly, while the user is still typing.
sealed class UsernameCheck {
  const UsernameCheck();
}

final class UsernameValid extends UsernameCheck {
  const UsernameValid(this.normalised);

  /// What should actually be stored — lowercased and trimmed.
  final String normalised;
}

final class UsernameInvalid extends UsernameCheck {
  const UsernameInvalid(this.problem);

  final UsernameProblem problem;
}

abstract final class UsernameRules {
  static const int minLength = 3;
  static const int maxLength = 20;

  /// Handles nobody may take.
  ///
  /// Brand and authority words, because `@aura` or `@support` sending someone
  /// -300 would read as coming from the app itself. Plus the words that mean
  /// something in a mention context (`@everyone`, `@here`) and the strings that
  /// look like bugs if they show up as a name (`null`, `undefined`, `deleted`).
  ///
  /// Every entry must be a name that would *otherwise* pass every other rule —
  /// an entry that is already unreachable (too short, bad characters) reads as
  /// protection while doing nothing. A test enforces this.
  static const Set<String> reserved = {
    'aura', 'auraapp', 'apexverse', 'admin', 'administrator', 'root', 'system',
    'support', 'help', 'helpdesk', 'official', 'team', 'staff', 'moderator',
    'mod', 'security', 'billing', 'legal', 'privacy', 'abuse', 'report',
    'everyone', 'here', 'all', 'null', 'undefined', 'none', 'anonymous',
    'deleted', 'unknown', 'you',
  };

  static final RegExp _allowed = RegExp(r'^[a-z0-9_]+$');
  static final RegExp _startsWithLetter = RegExp(r'^[a-z]');

  /// Lowercases and trims. Also strips a leading `@`, because people type the
  /// handle the way they read it.
  static String normalise(String raw) {
    var value = raw.trim().toLowerCase();
    while (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  /// Checks a candidate. Order matters: the most specific, most actionable
  /// problem should win, so "you can't start with a number" beats a generic
  /// "bad characters" when both are true.
  static UsernameCheck check(String raw) {
    final value = normalise(raw);

    if (value.isEmpty) return const UsernameInvalid(UsernameProblem.empty);
    if (value.length < minLength) {
      return const UsernameInvalid(UsernameProblem.tooShort);
    }
    if (value.length > maxLength) {
      return const UsernameInvalid(UsernameProblem.tooLong);
    }
    if (!_allowed.hasMatch(value)) {
      return const UsernameInvalid(UsernameProblem.badCharacters);
    }
    if (!_startsWithLetter.hasMatch(value)) {
      return const UsernameInvalid(UsernameProblem.mustStartWithLetter);
    }
    // `a__b` and `a_b` are near-indistinguishable at a glance, which is exactly
    // the impersonation gap the character restriction above is meant to close.
    if (value.contains('__')) {
      return const UsernameInvalid(UsernameProblem.doubleUnderscore);
    }
    if (value.endsWith('_')) {
      return const UsernameInvalid(UsernameProblem.trailingUnderscore);
    }
    if (reserved.contains(value)) {
      return const UsernameInvalid(UsernameProblem.reserved);
    }

    return UsernameValid(value);
  }

  /// Alternates to offer when the chosen name is taken — spec §5.3 asks for
  /// suggestions rather than a dead end.
  ///
  /// Numeric suffixes only, and never a birth year, because appending one would
  /// publish the age of a user base that includes minors. Each candidate is run
  /// back through [check] so a suggestion can never itself be invalid (e.g. a
  /// suffix pushing a 19-character name over the limit).
  static List<String> suggestionsFor(String raw, {int count = 3}) {
    final base = normalise(raw);
    if (base.isEmpty) return const [];

    final suggestions = <String>[];
    // Trim the base so there is room for the suffix rather than emitting
    // candidates that fail the length rule.
    for (final suffix in const ['1', '7', '22', '_x', '99', '_real']) {
      if (suggestions.length >= count) break;

      final maxBase = maxLength - suffix.length;
      final trimmed = base.length > maxBase ? base.substring(0, maxBase) : base;
      final candidate = '$trimmed$suffix';

      if (candidate == base) continue;
      if (suggestions.contains(candidate)) continue;
      if (check(candidate) is! UsernameValid) continue;

      suggestions.add(candidate);
    }
    return suggestions;
  }
}
