/// Every number the product rests on, in one place.
///
/// These constants are duplicated in the Cloud Functions (the client cannot be
/// trusted to enforce them, so the server checks them again). **If you change a
/// value here, change it there too** — a mismatch means either the client shows
/// a limit the server rejects, or the server accepts something the UI said was
/// impossible. There is no shared-code mechanism between Dart and the Node
/// functions, so this is enforced by a test that reads both files. See
/// `test/rules_parity_test.dart`.
///
/// Sources: spec §3.1 (point range, 80-char reason), §3.2 (baseline 1000),
/// §10 (asymmetric caps, minor safety).
library;

/// Score, point, and text limits.
abstract final class AuraRules {
  /// Everyone starts here. Spec §3.2 picked 1000 for the credit-score echo —
  /// it reads as "neutral", and it means a single bad day cannot take you to
  /// zero, which matters for an app about social judgment.
  static const int startingScore = 1000;

  /// Longest a custom (non-chip) reason may be. Spec §3.1: "meme-length".
  /// Counted in characters *after* trimming, so trailing spaces cannot be used
  /// to pad past a chip's meaning.
  static const int maxCustomReasonLength = 80;

  /// The absolute ceiling in the data model, regardless of who is sending.
  /// Spec §3.1 quotes -500..+500 as the range; §10 then tightens the negative
  /// side for everyone (see [pointCapsFor]). This pair exists so validation of
  /// *stored* data has a fixed bound even if the per-user caps change.
  static const int hardMinPoints = -500;
  static const int hardMaxPoints = 500;

  /// Caps that actually apply to a send, which depend on whether the sender is
  /// a minor.
  ///
  /// Spec §10 requires two things: negatives capped lower than positives
  /// ("-300 max vs +500 max") *and* "negative point caps lower" again for
  /// minors. The minor numbers are halved from the adult ones — the spec gives
  /// no figure, so this is a judgement call, recorded here rather than buried
  /// in a screen.
  static PointCaps pointCapsFor({required bool isMinor}) {
    return isMinor
        ? const PointCaps(maxPositive: 300, maxNegative: -150)
        : const PointCaps(maxPositive: 500, maxNegative: -300);
  }

  /// How many negative transactions one person may send to one other person
  /// before being blocked, and over what window. Spec §10 requires the limit
  /// but names no number; five in a rolling day stops a pile-on while leaving
  /// normal friend-group banter alone.
  static const int maxNegativesToSamePersonPerWindow = 5;
  static const Duration negativeRateLimitWindow = Duration(hours: 24);
}

/// The positive and negative bounds for one sender. [maxNegative] is negative.
final class PointCaps {
  const PointCaps({required this.maxPositive, required this.maxNegative});

  final int maxPositive;
  final int maxNegative;

  /// True when [points] is inside the caps and is not zero.
  ///
  /// Zero is rejected deliberately: a zero-point transaction would create a
  /// feed entry and a notification that says nothing happened, which is a free
  /// way to spam someone while staying under every other limit.
  bool allows(int points) {
    if (points == 0) return false;
    return points >= maxNegative && points <= maxPositive;
  }

  /// Clamps to the caps without changing sign. Used by the point slider so the
  /// UI cannot even offer an out-of-range value.
  int clamp(int points) {
    if (points > maxPositive) return maxPositive;
    if (points < maxNegative) return maxNegative;
    return points;
  }
}

/// Age rules. Separate from [AuraRules] because the reasoning is legal and
/// safety-driven, not product-tuning, and it should be read on its own.
abstract final class AuraAgeRules {
  /// Below this, no account. A locked project decision: the audience is 15–22
  /// (spec §2.3), and supporting under-15s would pull in stricter regimes
  /// (COPPA and equivalents) that the MVP is not built for.
  static const int minimumAge = 15;

  /// At or above this, the account gets adult defaults.
  static const int adultAge = 18;

  /// Age derived from a birth *year* alone — deliberately the lowest age the
  /// year can imply.
  ///
  /// Signup asks for a year, not a full date (spec §5.3 keeps the flow short),
  /// so a 2011 birth year in 2026 means the person is either 14 or 15
  /// depending on a month we did not ask for. This returns 14.
  ///
  /// **This over-blocks**, by up to a year, someone who has already had their
  /// birthday. That is the intended direction of error: letting a 14-year-old
  /// in is a safety failure, making a 15-year-old wait is an inconvenience.
  /// The same conservatism applies at the [adultAge] boundary, where it means
  /// a fresh 18-year-old keeps minor protections for a while — also the safe
  /// side. If this proves too blunt in the beta, the fix is to ask for a full
  /// date of birth, not to relax the arithmetic.
  static int conservativeAgeFor({required int birthYear, required int inYear}) {
    return inYear - birthYear - 1;
  }
}

/// Outcome of the signup age gate.
enum AgeGateResult {
  /// Under [AuraAgeRules.minimumAge]. No account.
  tooYoung,

  /// Old enough, but under [AuraAgeRules.adultAge] — `isMinor: true`, lower
  /// point caps, leaderboards off by default.
  minor,

  /// Adult defaults.
  adult,

  /// The year itself is not usable — a typo, the future, or implausibly old.
  invalidYear;

  bool get canCreateAccount => this == minor || this == adult;
  bool get isMinor => this == minor;
}

/// Decides the age gate from a birth year.
///
/// [today] is injected rather than read from the clock so this is testable and
/// so the result cannot silently change between the gate and the write.
AgeGateResult evaluateAgeGate({required int birthYear, required DateTime today}) {
  // A plausibility window, not an age check. 120 years back rules out typos
  // like 1099; the current year rules out the future. Without this, a birth
  // year of 3000 would come out as a large negative age and read as "too
  // young", which is technically the safe answer but a useless error message.
  if (birthYear > today.year || birthYear < today.year - 120) {
    return AgeGateResult.invalidYear;
  }

  final age = AuraAgeRules.conservativeAgeFor(
    birthYear: birthYear,
    inYear: today.year,
  );

  if (age < AuraAgeRules.minimumAge) return AgeGateResult.tooYoung;
  if (age < AuraAgeRules.adultAge) return AgeGateResult.minor;
  return AgeGateResult.adult;
}
