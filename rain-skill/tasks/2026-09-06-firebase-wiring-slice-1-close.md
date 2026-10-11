---
task-id: 2026-09-06-firebase-wiring-slice-1-close
flow: FEATURE
status: BLOCKED
started: 2026-09-06
completed: —
---

# Task: Connect the app to Firebase and close out Slice 1

## Flow: FEATURE

## Brainstorm

Answered by the user on 2026-09-06:

| Question | Answer |
|---|---|
| Phone OTP needs the paid Blaze plan — how should login work? | **Stay on free Spark, use email + password for the beta** |
| What to build next once Firebase is connected? | **Finish Slice 1 properly** |

## What is actually on the ground

Checked directly, not assumed:

| Thing | State |
|---|---|
| Firebase project `aura-d68c3` | ✅ exists (project number 854265933653) |
| Firebase CLI | ✅ test/deploy command pinned to v13.35.1 for this machine's Java 17 runtime |
| Firestore database | ✅ `(default)`, native mode, STANDARD edition |
| Android app registered | ✅ `1:854265933653:android:a52a8d4c730e2adb6f49dc` |
| `lib/firebase_options.dart` | ✅ generated for Android |
| `android/app/google-services.json` | ✅ present and intentionally tracked |
| `Firebase.initializeApp` in `main.dart` | ✅ awaited before `runApp` |
| Cloud Storage bucket | ❌ **not provisioned** — `HTTP 404` on the bucket URL |

The plan's long-standing "⛔ Firebase is the one blocker" note was stale. The
project and wiring now exist. The remaining Spark-plan consequences are recorded
below.

## Two consequences of the Spark decision, stated up front

Neither is a blocker for this task, but both change what Slice 1 can honestly
claim to be finished, so they are recorded before any code is written.

**1. Login stops matching the spec.** §5.3 specifies phone → OTP. Email + password
is a different flow with a different screen. The knock-on lands in **Slice 2**:
contact matching finds friends by hashing phone numbers, and an account created
by email has no phone number to hash. Slice 2 will therefore need either a
"add your number" step later, or a different friend-finding mechanism
(username search / invite link). This is a real narrowing of the product, taken
deliberately to avoid a billing commitment during development.

**2. Camera-first photo upload cannot be built.** The Storage bucket returns 404,
i.e. it has never been created. *I believe* new Firebase projects require the
Blaze plan to provision Cloud Storage — please treat that as unverified until we
try, but the 404 is certain either way: there is no bucket to upload to. So the
§5.3 photo step will be built as UI + a repository interface with no
implementation, and marked blocked, rather than half-wired.

## Plan

### Step 1 — Generate the Firebase config *(me)*
- [x] Generate the Android Firebase configuration for `aura-d68c3`
- [x] Confirm `lib/firebase_options.dart` and `android/app/google-services.json` exist
- [x] Confirm `google-services.json` is not gitignored while signing keys and service-account JSON stay ignored
→ Verify: both files exist, `flutter analyze` clean

### Step 2 — Initialize Firebase at startup *(me)*
- [x] Replace the comment in `main.dart` with an awaited `Firebase.initializeApp`
- [x] Handle the "already initialized" case so hot restart does not throw
- [x] Add `firebase_auth`, `cloud_firestore` to `pubspec.yaml`
→ Verify: `flutter build apk --debug` succeeds, app boots to splash

### Step 3 — Firestore security rules *(me, then you review)*
The rules are the only thing standing between a modified client and someone
setting their own score to a million, so they get written before any client write.
- [x] `firestore.rules` implementing the three locked rules from the plan:
      client never writes `score` after create; create pins `score == 1000`;
      `usernames/{username}` claimable once and never reassigned
- [x] Minor protections: `isMinor` and `birthYear` immutable after create
- [x] Require the profile and matching username claim in the same atomic commit
- [x] Keep private profile fields self-readable only; cross-user public profiles move to Slice 2
- [x] `firestore.indexes.json` documents why Slice 1 needs no composite indexes
- [x] Rules unit tests (`@firebase/rules-unit-testing`) proving a client cannot
      raise its own score, cannot steal a username, cannot flip `isMinor`
- [x] Deploy with `firebase deploy --only firestore:rules`
→ Verify: rules tests pass locally against the emulator, deploy succeeds

### Step 4 — Email + password auth *(me)*
- [x] Confirm Email/Password is enabled using a non-account-creating Auth API probe
- [x] `AuthRepository` wrapping `firebase_auth`, exposing `authStateChanges()`
- [x] Replace the phone + OTP steps with email + password steps in the signup
      wizard, keeping the age gate and username steps exactly as they are
- [x] Run the age gate before creating the Firebase Auth account
- [x] Riverpod providers for auth state
- [x] Splash branches on real auth state instead of always going to onboarding
→ Verify: widget tests still green; a fake auth repo drives the flow in tests

### Step 5 — User + username repositories *(me)*
- [x] `UserRepository.createAccount` — claims `usernames/{username}` and creates
      `users/{uid}` in **one Firestore transaction**, so a crash cannot leave a
      claimed name with no user
- [x] `UserRepository.isUsernameAvailable` — the single cheap document read the
      username step has been waiting for; wire it into the live check and show
      `suggestionsFor` when taken
- [x] `watchUser(uid)` stream for the home screen
→ Verify: signup completes on your physical phone; `users/{uid}` exists with
  `score: 1000`; `usernames/{name}` points at that uid

### Step 6 — Photo step, honestly blocked *(me)*
- [ ] Camera-first picker and upload implementation *(blocked until Storage exists)*
- [x] `PhotoRepository` interface
- [x] Skippable, with the profile falling back to the orb (which is the better
      default anyway)
- [x] Storage 404 finding recorded without a fake upload path
→ Verify: skipping works; no fake upload success

### Step 7 — Close the slice
- [x] Update `aura-mvp-plan.md`: remove the stale Firebase blocker, record the
      Spark/email decision and its Slice 2 cost, record the Storage 404
- [x] `security-gate`
- [x] `post-task-review`
- [x] File the current outcome into `project-wiki`

## Things only you can do

- [x] **Email/Password sign-in enabled** — confirmed by Firebase Auth response on 2026-10-03.
- [ ] **Verify on your physical phone** once Step 5 lands: sign up, land on a real
      account, see 1000.
- [ ] *(Later, not now)* Blaze upgrade if you want phone OTP, contact matching, or
      photo upload. Not needed for anything in this task.

## Done When
- [x] The app initializes Firebase and builds a debug APK cleanly
- [x] Security rules are deployed and tested — 54/54 emulator tests pass
- [ ] You can sign up with email on your phone and a real `users/{uid}` exists with score 1000
- [ ] Widget tests green — blocked by Windows Application Control denying `flutter_tester.exe`
- [x] `flutter analyze` clean and debug APK builds
- [x] The plan tells the truth about what is deferred and why

## Notes

Order matters here and is not arbitrary: **rules before repositories**. Writing
the client first and the rules after means the client gets built against a
permissive backend and then breaks when the rules land — and the temptation at
that point is to loosen the rules rather than fix the client.

## Security Gate
Status: PASSED after remediation
Findings:
- ✅ Profile and username claim must be created atomically and cross-reference each other.
- ✅ Profile reads are self-only, protecting `birthYear`, `isMinor`, and privacy fields.
- ✅ The age gate runs before Firebase Auth account creation.
- ✅ Score, friend count, age state, username, and unknown fields remain client-immutable.
- ✅ `npm audit --audit-level=high` reports 0 vulnerabilities after updating the rules-test dependencies and pinning `@grpc/grpc-js` 1.14.5.
- ✅ The rules-test command pins a Java 17 compatible Firebase CLI instead of requiring a global install.
- 🟡 Known-handle lookup remains readable without auth for pre-account availability checks; list queries are denied and regression-tested.
- 🟡 `photoUrl` remains an arbitrary string until controlled Storage upload exists.

## Code Review
Status: APPROVED
Notes:
- ✅ Client transaction and server rules enforce the same atomic account invariant.
- ✅ Regression tests cover standalone claims, standalone profiles, mismatched pairs, private profile reads, score protection, and minor defaults.
- ✅ Signup no longer authenticates an under-age rejected user.
- 🟡 Slice 2 must add a separate minimal public-profile document rather than broadening reads on `users/{uid}`.

## Verification
Status: BLOCKED
Observed evidence:
- `flutter analyze` → exit 0, no issues found.
- Firestore emulator suite → exit 0, 54 passed / 0 failed.
- `npm audit --audit-level=high` → exit 0, 0 vulnerabilities.
- `flutter build apk --debug` → exit 0, APK built successfully.
- Firestore rules deploy → exit 0, compiled and released to `aura-d68c3`.
- Email/password provider probe → `INVALID_EMAIL`, confirming the provider is enabled without creating an account.
Blockers:
- `flutter test` cannot start because Windows Application Control blocks `flutter_tester.exe`.
- No Android device is connected for the real signup/account smoke test.

## Final Status: BLOCKED — automated widget runner and physical-device verification unavailable
