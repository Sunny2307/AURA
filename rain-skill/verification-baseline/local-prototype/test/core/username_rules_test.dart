import 'package:aura/core/validation/username_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Convenience so the assertions read as intent, not as pattern matching.
UsernameProblem? problemFor(String raw) {
  final result = UsernameRules.check(raw);
  return result is UsernameInvalid ? result.problem : null;
}

String? normalisedFor(String raw) {
  final result = UsernameRules.check(raw);
  return result is UsernameValid ? result.normalised : null;
}

void main() {
  group('accepts', () {
    test('an ordinary handle', () {
      expect(normalisedFor('sam'), 'sam');
    });

    test('letters, digits and single underscores', () {
      expect(normalisedFor('sam_1'), 'sam_1');
      expect(normalisedFor('a1b2c3'), 'a1b2c3');
      expect(normalisedFor('main_character'), 'main_character');
    });

    test('the shortest and longest allowed lengths', () {
      expect(normalisedFor('abc'), 'abc');
      final longest = 'a' * UsernameRules.maxLength;
      expect(normalisedFor(longest), longest);
    });
  });

  group('normalises', () {
    test('case, so sam and Sam cannot both exist', () {
      expect(normalisedFor('SAM'), 'sam');
      expect(normalisedFor('SaM_Doe'), 'sam_doe');
    });

    test('surrounding whitespace from a paste or an autocorrect space', () {
      expect(normalisedFor('  sam  '), 'sam');
    });

    test('a leading @, because people type the handle as they read it', () {
      expect(normalisedFor('@sam'), 'sam');
      expect(normalisedFor('@@sam'), 'sam');
    });
  });

  group('rejects', () {
    test('empty and whitespace-only input', () {
      expect(problemFor(''), UsernameProblem.empty);
      expect(problemFor('   '), UsernameProblem.empty);
      expect(problemFor('@'), UsernameProblem.empty);
    });

    test('too short and too long', () {
      expect(problemFor('ab'), UsernameProblem.tooShort);
      expect(problemFor('a' * (UsernameRules.maxLength + 1)),
          UsernameProblem.tooLong);
    });

    test('punctuation, spaces and emoji', () {
      expect(problemFor('sam!'), UsernameProblem.badCharacters);
      expect(problemFor('sam.doe'), UsernameProblem.badCharacters);
      expect(problemFor('sam doe'), UsernameProblem.badCharacters);
      expect(problemFor('sam-doe'), UsernameProblem.badCharacters);
      expect(problemFor('sam🔥'), UsernameProblem.badCharacters);
    });

    test('lookalike unicode, which is the impersonation case', () {
      // 'pаul' with U+0430 CYRILLIC SMALL LETTER A. Visually identical to
      // 'paul' in most fonts. On an app about attributing judgment to a named
      // person, letting this register would be a safety hole, not a nitpick.
      expect(problemFor('pаul'), UsernameProblem.badCharacters);
    });

    test('names that do not start with a letter', () {
      expect(problemFor('1sam'), UsernameProblem.mustStartWithLetter);
      expect(problemFor('_sam'), UsernameProblem.mustStartWithLetter);
      expect(problemFor('123'), UsernameProblem.mustStartWithLetter);
    });

    test('doubled and trailing underscores', () {
      expect(problemFor('sa__m'), UsernameProblem.doubleUnderscore);
      expect(problemFor('sam_'), UsernameProblem.trailingUnderscore);
    });

    test('reserved brand and authority handles', () {
      expect(problemFor('aura'), UsernameProblem.reserved);
      expect(problemFor('admin'), UsernameProblem.reserved);
      expect(problemFor('support'), UsernameProblem.reserved);
      expect(problemFor('apexverse'), UsernameProblem.reserved);
      expect(problemFor('everyone'), UsernameProblem.reserved);
    });

    test('reserved handles even when disguised by case or an @', () {
      expect(problemFor('@Admin'), UsernameProblem.reserved);
      expect(problemFor('  AURA '), UsernameProblem.reserved);
    });
  });

  test('every reserved word would otherwise be a valid username', () {
    // If a reserved entry could never be typed anyway (too short, bad
    // characters), it is dead weight in the set and probably a mistake.
    for (final word in UsernameRules.reserved) {
      final withoutReservedCheck = word.length >= UsernameRules.minLength &&
          word.length <= UsernameRules.maxLength &&
          RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(word) &&
          !word.contains('__') &&
          !word.endsWith('_');
      expect(
        withoutReservedCheck,
        isTrue,
        reason: '"$word" is in the reserved set but could never be entered',
      );
    }
  });

  group('suggestions', () {
    test('are offered when a name is taken', () {
      final suggestions = UsernameRules.suggestionsFor('sam');
      expect(suggestions, hasLength(3));
      expect(suggestions, everyElement(isNot('sam')));
    });

    test('are themselves always valid', () {
      for (final input in ['sam', 'a' * 20, 'main_character', 'x1']) {
        for (final suggestion in UsernameRules.suggestionsFor(input)) {
          expect(
            UsernameRules.check(suggestion),
            isA<UsernameValid>(),
            reason: 'suggestion "$suggestion" for "$input" is not valid',
          );
        }
      }
    });

    test('stay within the length limit even for a maximum-length base', () {
      final suggestions = UsernameRules.suggestionsFor('a' * 20);
      expect(suggestions, isNotEmpty);
      for (final suggestion in suggestions) {
        expect(suggestion.length, lessThanOrEqualTo(UsernameRules.maxLength));
      }
    });

    test('contain no duplicates', () {
      final suggestions = UsernameRules.suggestionsFor('sam', count: 6);
      expect(suggestions.toSet(), hasLength(suggestions.length));
    });

    test('never include a birth year, which would publish someone age', () {
      // Minors are in scope, so a suggestion like sam2009 would leak an age.
      final suggestions = UsernameRules.suggestionsFor('sam', count: 8);
      for (final suggestion in suggestions) {
        expect(
          RegExp(r'(19|20)\d\d').hasMatch(suggestion),
          isFalse,
          reason: '"$suggestion" looks like it contains a birth year',
        );
      }
    });

    test('are empty for input that cannot be salvaged', () {
      expect(UsernameRules.suggestionsFor(''), isEmpty);
      expect(UsernameRules.suggestionsFor('@'), isEmpty);
    });
  });
}
