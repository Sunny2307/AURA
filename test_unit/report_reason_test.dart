/// Keeps the report reasons inside what the security rules will accept.
///
/// `firestore.rules` requires `reason` to be a non-empty string of at most 40
/// characters. If an enum value ever broke that, every report using it would be
/// rejected with a bare `permission-denied` — which reads as a rules bug and
/// would be looked for in entirely the wrong place.
///
/// Runs under `dart test test_unit`, which matters because `flutter test`
/// cannot run on this machine at all.
library;

import 'package:aura/core/models/report_reason.dart';
import 'package:test/test.dart';

void main() {
  group('ReportReason', () {
    test('every wire value fits what the rules accept', () {
      for (final reason in ReportReason.values) {
        expect(
          reason.wireValue,
          isNotEmpty,
          reason: '${reason.name} would be rejected as an empty reason',
        );
        expect(
          reason.wireValue.length,
          lessThanOrEqualTo(ReportReason.maxWireLength),
          reason: '${reason.name} exceeds the cap in firestore.rules',
        );
      }
    });

    test('wire values are distinct', () {
      final seen = ReportReason.values.map((r) => r.wireValue).toSet();
      expect(seen, hasLength(ReportReason.values.length));
    });

    test('wire values are stable identifiers, not display text', () {
      // Display text changes with copy edits; stored values must not. This
      // catches someone "tidying" the enum by setting wireValue from label.
      for (final reason in ReportReason.values) {
        expect(reason.wireValue, matches(RegExp(r'^[a-z][a-z_]*$')));
      }
    });

    test('every reason has a human label, not an identifier', () {
      // Deliberately not "label != name": `harassment` is correctly both. What
      // this catches is a label that leaked an identifier — snake_case or
      // camelCase text rendered at a user.
      for (final reason in ReportReason.values) {
        expect(reason.label, isNotEmpty);
        expect(reason.label, isNot(contains('_')));
        expect(reason.label, matches(RegExp(r'^[a-z][a-z \-]*$')));
      }
    });

    test('covers the three §10 names explicitly', () {
      // Spec §10 calls out harassment, slurs and self-harm by name. Losing one
      // in a refactor would quietly narrow what people can report.
      final values = ReportReason.values.map((r) => r.wireValue);
      expect(values, contains('harassment'));
      expect(values, contains('hate_speech'));
      expect(values, contains('self_harm'));
    });
  });
}
