---
task-id: 2026-09-06-slice-1-onboarding
flow: FEATURE
status: DONE
started: 2026-09-06T00:00:00+00:00
completed: —
---

# Task: Start Slice 1 with the offline onboarding flow

## Flow: FEATURE

## Brainstorm
N/A (FEATURE — existing MVP plan defines the scope and sequence)

## Plan
- [x] Add the four-screen onboarding experience using the existing Aura design system
- [x] Replace the design-check-only initial route with onboarding
- [x] Security gate — PASS
- [x] Code review — PASS
- [x] Verification — PASS

## Implementation Notes
Smart Flow detected Slice 1 as the next actionable work. Firebase setup remains an external blocker, so this task intentionally implements only the local onboarding UI and navigation.

Implemented `OnboardingScreen` with four swipeable pages, accessible page semantics, back/next controls, and a Firebase-free final placeholder. The app now starts at `/`; the existing design-check route remains available at `/_design`. Also completed the pre-existing `AppRouter.replaceWith` helper required by the splash screen.

## Security Gate
PASS — No secrets, network calls, authentication state, PII, contact data, or persistence were introduced. The final action does not claim signup succeeded; it only surfaces the next Firebase-dependent step.

## Code Review
PASS — Scope is limited to the first actionable Slice 1 UI. Existing design-system widgets and theme tokens are reused; Firebase remains intentionally untouched.

## Verification
PASS — `flutter analyze` reports no issues, `flutter test` passes all 74 tests after formatting, and `flutter build apk --debug` succeeds. The build repeats the known non-blocking warning that `firebase_core` still applies the Kotlin Gradle Plugin.

## Final Status: DONE ✅
