# Architecture

Aura is a Flutter mobile app under `app/`, using Riverpod for dependency
injection and live state, GoRouter for navigation, Firebase Auth for beta
credentials, and Cloud Firestore for profiles, unique username claims, public
discovery profiles and friendships.

Normal startup runs a persistent local prototype without Firebase or the Node.js
API. `app/lib/main.dart` loads `app/lib/prototype/prototype_runtime.dart`, which
overrides auth, profiles, friendships, safety, deletion and aura-send providers.
See [[features/local-app-prototype]]. Explicit `AURA_PROTOTYPE=false` selects the
original integration mode and initializes Firebase before `runApp`.

## Layering

Auth, user, public-profile and friendship access all sit behind repository
interfaces — `app/lib/features/auth/data/` and `app/lib/features/friends/data/` —
each with a production Firebase implementation and an in-memory fake in
`app/test/support/fake_repositories.dart`.

The interfaces exist for the fakes. A widget test that had to reach Firebase
would need an emulator, a network and a JDK, and would still be unable to produce
the interesting cases on demand: a handle claimed half a second ago, a request
cancelled between read and write, a dropped connection mid-transaction.

Features are organised `data/` → `application/` → `presentation/`, one folder per
feature under `lib/features/`.

Routing is in `app/lib/core/router/app_router.dart`. There is no global auth
redirect — the splash screen branches on `SignupStatus`, and the slice-2 screens
carry a **per-route** guard. A global guard would have to encode "signed in but
mid-signup is allowed on /signup and only there", which means the router knowing
the signup flow's internals.

## Authorization

The future integration mode remains on Firebase **Spark**. `app/firestore.rules` enforces
permissions on direct mobile writes. The local `backend/` Node.js API uses
Firebase Admin credentials to validate aura sends and atomically update scores,
transactions, rate limits and sender/recipient feeds. Admin writes bypass
Firestore rules, so the API must enforce all send invariants itself. See
[[features/node-backend]].

## Presentation

The shared theme and `app/lib/shared/widgets/aura_identity.dart` implement the
mint-and-ink visual identity. Home, people and settings use labeled navigation;
send remains a persistent home action. Layouts preserve OS text scaling, scroll
around the keyboard, and cap the content width at 640 logical pixels. Demo
controls are secondary, with explicit device-only labeling. Repository contracts,
stored data and route guards are preserved. See [[design-system]].

The rules are tested against the emulator in
`app/firestore-tests/rules.test.js`, 143 cases as of slice 9. The threat model is
not an anonymous stranger: it is a user of the app who has decompiled it, or who
is driving the Firestore REST API with their own valid ID token.

## Testing, and what actually runs here

| Suite | Command | Runs on this machine |
|---|---|---|
| Security rules | `npm test` in `app/firestore-tests/` | ✅ yes |
| Pure-Dart models | `dart test test_unit` | ✅ yes |
| Widget tests | `flutter test --no-pub` | ✅ runs with approved runtime access |

The earlier Windows restriction was rechecked on 2026-10-11: widget tests now
run through the approved Flutter runtime. Five existing widget tests fail in the
original baseline (friend self-search, two signup credential fixtures, blocking,
and deletion). The redesign adds layout, keyboard and real-router flow coverage.
`test_unit/` remains a parallel tree of Flutter-free model and store tests.
See `docs/rain-skill/tasks/2026-10-11-gen-z-ui-redesign.md` for observed results.

The Firebase CLI needs JDK 17 on **PATH**, not merely in `JAVA_HOME` — `java`
resolves to Oracle Java 8 here, and the emulator refuses to start.

## Platforms

The Windows development machine builds Android locally. iOS build, signing and
device validation require macOS and are deferred — the Flutter code itself is
shared, so what is blocked is building and testing, not app logic.

Invite links use the `aura://` custom scheme registered in the Android manifest.
An `https://` App Link would survive the app not being installed but needs a
registered domain. See [[open-questions]].

## Sources

- Code: `app/lib/main.dart`, `app/lib/core/router/app_router.dart`,
  `app/lib/features/auth/`, `app/lib/features/friends/`, `app/firestore.rules`
- Tasks: `docs/rain-skill/tasks/2026-09-06-firebase-wiring-slice-1-close.md`,
  `docs/rain-skill/tasks/2026-10-03-slice-2-find-friends.md`
