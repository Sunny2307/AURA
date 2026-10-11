/// Why someone was reported.
///
/// A closed set rather than free text, for three reasons:
///
/// 1. Nobody is reviewing the report queue yet. A fixed vocabulary can be
///    counted and sorted from the Firebase console; free text cannot.
/// 2. Free text from a user about another named user is itself content that
///    would need moderating — the report form would become the unmoderated
///    channel the report form exists to address.
/// 3. The security rules cap `reason` at 40 characters. An enum makes that
///    impossible to breach by construction, and [maxWireLength] plus its test
///    keep the two in step.
///
/// Spec §10 names harassment, slurs and self-harm explicitly. The rest are the
/// ordinary reasons people report each other in a social app.
enum ReportReason {
  harassment('harassment'),
  bullying('bullying'),
  hateSpeech('hate_speech'),
  selfHarm('self_harm'),
  impersonation('impersonation'),
  spam('spam'),
  somethingElse('something_else');

  const ReportReason(this.wireValue);

  /// Stored as a string rather than an index, so reordering this enum can never
  /// silently reinterpret existing reports.
  final String wireValue;

  /// Must match the cap in `firestore.rules`. If this ever grows past it, every
  /// report using the longer value is rejected with a bare permission error
  /// that looks like a rules bug — which is why `test_unit/` asserts it.
  static const int maxWireLength = 40;

  /// Shown in the report sheet. Lowercase, matching the app's voice.
  String get label => switch (this) {
    ReportReason.harassment => 'harassment',
    ReportReason.bullying => 'bullying',
    ReportReason.hateSpeech => 'hate speech or slurs',
    ReportReason.selfHarm => 'self-harm or suicide',
    ReportReason.impersonation => 'pretending to be someone',
    ReportReason.spam => 'spam',
    ReportReason.somethingElse => 'something else',
  };
}
