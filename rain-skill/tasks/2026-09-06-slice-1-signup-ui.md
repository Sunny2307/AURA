---
task-id: 2026-09-06-slice-1-signup-ui
flow: FEATURE
status: DONE
started: 2026-09-06T00:00:00+00:00
completed: 2026-09-06
---

# Task: Implement the Firebase-independent Slice 1 signup flow

## Flow: FEATURE

## Brainstorm
N/A (FEATURE — the MVP plan defines the signup sequence)

## Plan
- [x] Wire splash -> onboarding -> signup navigation
- [x] Build phone, OTP, age gate, username, and review screens
- [x] Reuse shared age and username validation rules
- [x] Security gate — PASS
- [x] Code review — PASS
- [x] Verification — PASS

## Implementation Notes
The signup wizard validates phone shape, six-digit OTP shape, the existing conservative 15+ age gate, and the existing username rules. It intentionally does not send an OTP, query username availability, create a Firestore user, or upload a photo until Firebase is configured.

## Security Gate
PASS — No credentials, fake authentication, Firestore writes, Storage writes, or client-trusted account creation were added. The UI explicitly reports that Firebase setup is required to finish signup.

## Code Review
PASS — Scope is limited to local Slice 1 UI and navigation. Existing rule and model abstractions are reused; no duplicate age or username policy was introduced.

## Verification
PASS — `flutter analyze`, `flutter test` (74 tests), and `flutter build apk --debug` all pass. Build retains the known non-blocking `firebase_core` KGP warning.

## Final Status: DONE ✅
