---
task-id: 2026-09-06-onboarding-art-and-flow-tests
flow: FEATURE
status: DONE
started: 2026-09-06
completed: 2026-09-06
---

# Task: Wire the real onboarding art, add §5.3 name suggestions, cover the flow with tests

## Flow: FEATURE

## Brainstorm
N/A (FEATURE — the MVP plan and spec §5.2/§5.3/§7.4 define the scope)

## Plan
- [x] Replace the onboarding screen's inline visuals with the four `Onboarding*Art` widgets
- [x] Restore §7.4 copy verbatim on pages 3 and 4
- [x] Wire `UsernameRules.suggestionsFor` into the username step (§5.3 "suggest alternates if taken")
- [x] Rewrite the signup wizard's step index as a named enum
- [x] Add widget tests proving the age gate and username rules block, not warn
- [x] Security gate — PASS
- [x] Code review — PASS
- [x] Verification — PASS

## Implementation Notes

Three real gaps found on picking the work back up, all of them the kind that
survive a green build:

1. **The four `Onboarding*Art` widgets were orphaned.** `onboarding_screen.dart`
   had grown its own private `_ScoreVisual` / `_TransactionVisual` /
   `_PrivacyVisual` / `_ReadyVisual`, so the app carried two parallel sets of
   onboarding illustrations and rendered the wrong one. Deleted the inline set;
   the screen now uses the shared art built from real `AuraOrb` / `AuraCard` /
   `AuraPoints`. This is the point of that file existing — art drawn separately
   drifts from the product one theme tweak at a time.

2. **Copy had drifted from §7.4.** Page 3 read "or hide it. your call." against
   the spec's "or keep it private. your call.", and page 4 had been replaced
   wholesale with "make your mark. / sign up when you are ready to enter the
   circle." — losing the contacts framing §5.2 asks for. Both restored verbatim,
   with a doc comment saying to change the spec first if the copy needs to move.

3. **`UsernameRules.suggestionsFor` was written, tested, and never called.** §5.3
   requires "suggest alternates if taken", so the username step now shows tappable
   `ActionChip` alternates for any rejected name — not only a taken one, since
   someone who typed `Sam!` needs a way forward just as much.

Also fixed while in the file: `_step` was a bare `int` compared against literals
(`case 2:`), which is silently wrong the moment a step is inserted — now a
`_SignupStep` enum. The error text was missing a `liveRegion`, so a screen reader
never announced why the button did nothing. And the review step now states the
minor-safety defaults explicitly rather than applying them silently.

`onboarding_art.dart` also had two defects from the previous session: a `library;`
directive placed after the imports (invalid Dart), and an orb-art tween whose
`begin` equalled its `end`, which would have frozen the count-up it exists to
demonstrate. Both fixed.

**A finding worth carrying forward:** `AuraOrb` breathes on an endless
`repeat(reverse: true)`, so any widget test whose tree contains an orb can never
`pumpAndSettle` — it times out. The flow tests run under
`disableAnimations: true`, which is the same code path a reduce-motion user gets,
so the tests cover that path for free. Recorded in `aura-mvp-plan.md` because
every future test touching an orb screen hits it.

## Security Gate
PASS — Nothing was added that touches credentials, network, or persistence. The
three temptations were explicitly refused and documented: no hard-coded OTP
(would be a login bypass), no claimed username availability without the
`usernames/{username}` read, no fake signup success. Age-gate behaviour is
unchanged and now has tests proving it blocks rather than warns; the rejection
message deliberately does not explain the conservative arithmetic, which would
invite a retry with a different year.

## Code Review
PASS — Net effect is a deletion of duplicated widgets, not new surface. Existing
`AuraRules`, `AuraAgeRules` and `UsernameRules` are reused with no policy
duplicated into the UI; user-facing limits are interpolated from those constants
so the copy cannot drift from the rules. `int` step index replaced with an enum.

## Verification
PASS — observed output:

- `flutter analyze` → `No issues found! (ran in 11.4s)`
- `flutter test` → `00:04 +90: All tests passed!` (74 → 90; 16 new)
- `flutter build apk --debug` → `√ Built build\app\outputs\flutter-apk\app-debug.apk` (exit 0)

Build still emits the known non-blocking `firebase_core` KGP warning.

Not verified: anything requiring a device or Firebase. Visual confirmation is the
user's, on their own physical phone, per their standing instruction.

## Final Status: DONE ✅
