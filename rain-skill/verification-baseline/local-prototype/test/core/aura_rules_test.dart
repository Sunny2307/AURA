import 'package:aura/core/rules/aura_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('point caps', () {
    test('adults get the asymmetric caps from spec 10', () {
      final caps = AuraRules.pointCapsFor(isMinor: false);
      expect(caps.maxPositive, 500);
      expect(caps.maxNegative, -300);
    });

    test('minors get tighter caps on both sides', () {
      final adult = AuraRules.pointCapsFor(isMinor: false);
      final minor = AuraRules.pointCapsFor(isMinor: true);

      expect(minor.maxPositive, lessThan(adult.maxPositive));
      // "Lower" for a negative cap means closer to zero, so compare magnitudes
      // rather than the signed values — otherwise this assertion passes for a
      // minor cap that is actually *harsher*.
      expect(minor.maxNegative.abs(), lessThan(adult.maxNegative.abs()));
    });

    test('the negative cap is always tighter than the positive one', () {
      for (final isMinor in [true, false]) {
        final caps = AuraRules.pointCapsFor(isMinor: isMinor);
        expect(
          caps.maxNegative.abs(),
          lessThan(caps.maxPositive),
          reason: 'spec 10 requires negatives capped lower than positives',
        );
      }
    });

    test('allows values inside the caps and rejects the boundaries beyond', () {
      final caps = AuraRules.pointCapsFor(isMinor: false);

      expect(caps.allows(500), isTrue);
      expect(caps.allows(501), isFalse);
      expect(caps.allows(-300), isTrue);
      expect(caps.allows(-301), isFalse);
      expect(caps.allows(1), isTrue);
      expect(caps.allows(-1), isTrue);
    });

    test('rejects zero, which would be a free notification', () {
      expect(AuraRules.pointCapsFor(isMinor: false).allows(0), isFalse);
      expect(AuraRules.pointCapsFor(isMinor: true).allows(0), isFalse);
    });

    test('clamp keeps the sign and lands on the cap', () {
      final caps = AuraRules.pointCapsFor(isMinor: true);

      expect(caps.clamp(9999), 300);
      expect(caps.clamp(-9999), -150);
      expect(caps.clamp(50), 50);
      expect(caps.clamp(-50), -50);
    });

    test('every clamped value is then allowed, except zero', () {
      final caps = AuraRules.pointCapsFor(isMinor: false);
      for (var raw = -1000; raw <= 1000; raw += 37) {
        final clamped = caps.clamp(raw);
        if (clamped == 0) continue;
        expect(
          caps.allows(clamped),
          isTrue,
          reason: 'clamp($raw) produced $clamped, which allows() rejects',
        );
      }
    });
  });

  group('age gate', () {
    // Fixed date so these never break on New Year's Day.
    final today = DateTime(2026, 9, 4);

    test('birth year 2011 is rejected in 2026', () {
      // The plan records this exact case. It only holds because the age is
      // derived conservatively: 2011 could mean 14 or 15, and we assume 14.
      expect(
        evaluateAgeGate(birthYear: 2011, today: today),
        AgeGateResult.tooYoung,
      );
    });

    test('birth year 2009 is allowed and flagged as a minor', () {
      final result = evaluateAgeGate(birthYear: 2009, today: today);
      expect(result, AgeGateResult.minor);
      expect(result.isMinor, isTrue);
      expect(result.canCreateAccount, isTrue);
    });

    test('the youngest allowed year is a minor, the year before is blocked', () {
      // 2010 -> conservative age 15 -> exactly at the minimum.
      expect(evaluateAgeGate(birthYear: 2010, today: today), AgeGateResult.minor);
      expect(
        evaluateAgeGate(birthYear: 2011, today: today),
        AgeGateResult.tooYoung,
      );
    });

    test('the adult boundary lands where the conservative age turns 18', () {
      // 2008 -> 17 -> still protected. 2007 -> 18 -> adult.
      expect(evaluateAgeGate(birthYear: 2008, today: today), AgeGateResult.minor);
      expect(evaluateAgeGate(birthYear: 2007, today: today), AgeGateResult.adult);
    });

    test('adults are not flagged as minors', () {
      final result = evaluateAgeGate(birthYear: 1995, today: today);
      expect(result, AgeGateResult.adult);
      expect(result.isMinor, isFalse);
      expect(result.canCreateAccount, isTrue);
    });

    test('implausible years are rejected as invalid, not as too young', () {
      // A future year would otherwise compute a negative age and be reported
      // as "too young", which is a confusing thing to tell someone.
      expect(
        evaluateAgeGate(birthYear: 2027, today: today),
        AgeGateResult.invalidYear,
      );
      expect(
        evaluateAgeGate(birthYear: 3000, today: today),
        AgeGateResult.invalidYear,
      );
      expect(
        evaluateAgeGate(birthYear: 1099, today: today),
        AgeGateResult.invalidYear,
      );
      expect(
        evaluateAgeGate(birthYear: 0, today: today),
        AgeGateResult.invalidYear,
      );
    });

    test('the current year is plausible but far too young', () {
      expect(
        evaluateAgeGate(birthYear: 2026, today: today),
        AgeGateResult.tooYoung,
      );
    });

    test('no year both blocks the account and reports a usable state', () {
      for (var year = 1900; year <= 2030; year++) {
        final result = evaluateAgeGate(birthYear: year, today: today);
        if (result.canCreateAccount) {
          final age = AuraAgeRules.conservativeAgeFor(
            birthYear: year,
            inYear: today.year,
          );
          expect(
            age,
            greaterThanOrEqualTo(AuraAgeRules.minimumAge),
            reason: 'year $year created an account below the minimum age',
          );
          expect(
            result.isMinor,
            age < AuraAgeRules.adultAge,
            reason: 'year $year disagreed with the adult boundary',
          );
        }
      }
    });
  });

  group('constants', () {
    test('everyone starts at the baseline from spec 3.2', () {
      expect(AuraRules.startingScore, 1000);
    });

    test('custom reasons are capped at the meme length from spec 3.1', () {
      expect(AuraRules.maxCustomReasonLength, 80);
    });

    test('the per-user caps never exceed the hard stored bounds', () {
      for (final isMinor in [true, false]) {
        final caps = AuraRules.pointCapsFor(isMinor: isMinor);
        expect(caps.maxPositive, lessThanOrEqualTo(AuraRules.hardMaxPoints));
        expect(caps.maxNegative, greaterThanOrEqualTo(AuraRules.hardMinPoints));
      }
    });
  });
}
