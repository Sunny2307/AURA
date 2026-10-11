---
task-id: 2026-10-11-local-app-prototype
flow: FEATURE
status: DONE
started: 2026-10-11
completed: 2026-10-11
---

# Task: Make all app actions usable in a local prototype without backend integration

## Flow: FEATURE

## Brainstorm
User chose the recommended persistent local demo data: changes survive closing
and reopening the app. App-only prototype development is the current priority.
All existing actions should be usable without running the Node.js server or
connecting to Firebase.

Chosen approach: implement local repositories behind the existing interfaces,
sharing one persistent prototype store. This keeps screen behavior and data
consistent. Rejected approach: replace network errors with success messages in
screens; that would not update friends, scores or settings consistently.

## Plan
- [x] Make normal app startup use prototype mode and skip Firebase initialization.
  Keep real integrations isolated behind an explicit mode choice for future work;
  leave the standalone `backend/` directory separate and unchanged.
- [x] Add a persistent local store and repository implementations for auth,
  user profiles, public profiles, friendships, safety, aura sends and deletion.
  Persist session and mutations locally; do not store real passwords or tokens.
  Preserve existing repository contracts and reactive stream updates.
- [x] Seed useful demo profiles, accepted friends, incoming requests and searchable
  people so actions can be tried immediately after signup. Provide a demo entry /
  return path and a reset-demo action to repeat onboarding and destructive flows.
- [x] Make all existing app actions work locally: signup and username checks,
  sign-out and returning to an account, search and profile previews, friend request
  send/accept/decline/cancel/remove, invite links, positive/negative aura sends,
  privacy changes, reporting, block/unblock, and account deletion. Maintain ordinary
  validation and business rules so both success and rejected-action states can be
  tested. Sending updates recipient data rather than silently changing the sender.
- [x] Make the existing photo step usable without cloud storage, with a locally
  saved selected photo and a working skip option. Ensure local photos display
  wherever profiles currently show an avatar.
- [x] Show a concise prototype indicator and controls for repeatable testing.
  Demo actions must update real local state rather than only display a success
  message. Keep existing visual styling and navigation.
- [x] Add meaningful tests for local actions, cross-repository consistency,
  persistence/reload, reset, account deletion and startup without Firebase.
  Run formatting, Flutter analysis, available unit/widget tests and an Android
  build or device smoke check where the environment permits. Document any actual
  tool or device restriction rather than claiming unobserved success.
- [x] Security gate — PASSED
- [x] Code review — APPROVED
- [x] Verification — PASSED
- [x] Update app run instructions and project wiki for the prototype mode.

## Implementation Notes
Keep prototype data isolated from real Firebase/backend writes. Explore existing
repository interfaces and test fakes to support working local actions.

### Impact analysis
- Startup: `app/lib/main.dart`.
- Provider boundaries: auth, friends and safety application provider files,
  and `app/lib/features/send/data/aura_api.dart`.
- Existing interfaces: auth/user/public-profile/friendship/safety repositories,
  `AuraApi`, `AccountDeletionService`, and `PhotoRepository`.
- Screens potentially touched: onboarding/signup/photo, home, settings and
  profile avatar rendering; existing friend/send/safety screens use repositories.
- New prototype modules under `app/lib/`; persistence/photo packages in
  `app/pubspec.yaml` and lockfile only if needed.
- Existing test fakes are reference material; app runtime must not import tests.
- Existing home screen does not yet implement the future full feed/leaderboard.
  Scope is working existing actions and prototype controls, not building every
  future product-plan slice.
- Previous wiki reports Windows restrictions on Flutter widget-test execution;
  attempt fresh verification and record observed results.

### Contract and rollback
- Before: default providers instantiate Firebase repositories and HTTP aura API;
  startup initializes Firebase and photo selection is unavailable.
- After: prototype startup injects local implementations with matching contracts;
  Firebase/backend data remains isolated, and photo selection uses local storage.
- Trace all provider/interface callers before changing shared code, and keep
  contract-breaking changes out of production implementations.
- Preserve copies of files before editing because the app currently has untracked
  files; rollback must restore those copies, not rely on git restore.

## Security Gate
Status: PASSED
- Independent security-auditor reviewed the implementation and passed it.
- All seven service boundaries use local adapters; normal startup skips Firebase.
- Inputs, ownership, caps, privacy and send replay protection are enforced.
- No passwords/tokens saved; no backend writes or remote profile image requests.
- Photo deletion resolves paths and stays within private prototype photo storage.
- OSV Pub query checked 116 resolved packages: zero known advisories.
- Limitations: demo data is unencrypted, account switching is passwordless by
  design, photo cleanup is best-effort, and malformed saved data fails explicitly.
- Evidence: evidence/2026-10-11-local-app-prototype/prototype-dependency-audit.json.

## Code Review
Status: APPROVED
- Shared repository interfaces retained; local state commits before notifying.
- Failed saves roll back; concurrent mutations are serialized.
- Deleted sample accounts are not silently reseeded or added as ghost friends.
- Reports clearly indicate local simulation; options fit a scrollable sheet.
- Existing app flows retain validation; selected photos persist without uploads.
- No blocking findings. Future feed/leaderboard slices remain outside this task.

## Verification
Status: PASSED
- Fresh `dart test test_unit`: exit 0, 43 tests passed, including 16 store tests.
- Fresh `flutter test test/features/prototype_flow_test.dart test/features/send_aura_flow_test.dart`:
  exit 0, 3 widget tests passed, including two new prototype tests.
- Fresh `flutter analyze`: exit 0, no issues.
- Fresh `flutter build apk --debug`: exit 0, APK built successfully.
- Full Flutter suite: 122 passed, 5 failed (exit 1). Original-source baseline:
  118 passed, 7 failed (exit 1). All remaining failures match original test names;
  the scrollable report sheet resolves two original failures. No new failures.
- Remaining baseline failures: friends search own handle, signup email-in-use,
  signup disabled-provider, blocking friend list, deletion navigation. Existing
  test fixtures expect older signup timing / router / profile behavior.
- Full and baseline logs retained under evidence/2026-10-11-local-app-prototype/.
- Android APK installed successfully on CPH2613; activity launch succeeded.
  Visible device smoke check unavailable because the phone is locked. Widget
  tests exercise startup without Firebase, demo entry and recipient score updates.
- Original sources retained under docs/rain-skill/backups/2026-10-11-local-prototype.
- Updated app README and wiki architecture, prototype feature, index and decisions.

## Final Status: DONE

