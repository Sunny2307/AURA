---
task-id: 2026-10-04-spark-node-backend
flow: FEATURE
status: IN_PROGRESS
started: 2026-10-04
completed: —
---

# Task: Keep Firebase Spark and add a Node.js backend

## Confirmed constraints

- Firebase must remain on Spark; do not enable billing or upgrade services.
- Use Node.js for trusted backend work instead of the planned Firebase Cloud Functions.
- Reassess the previously documented Blaze blocker in the MVP plan.

## Brainstorm

User confirmed the Node.js server will run on the development computer. Chosen
approach 1: Flutter calls a local Node.js HTTP API to submit aura. The API
verifies Firebase Auth tokens and uses the Firebase Admin SDK for trusted
Firestore writes. The alternative, a Firestore-watching worker, was rejected
because it would need extra request-state and replay handling and would stop
processing whenever the local worker is offline.

## Plan

- [x] Add a local Node.js API with Firebase Admin credentials kept outside the repository, a health check, Firebase ID-token verification, bounded requests, and configuration for Android emulator and physical-phone development.
- [x] Implement the send-aura endpoint: verify completed sender/recipient accounts, accepted friendship, block/privacy rules, point and text caps, negative-send limits, and idempotency; update the **recipient** score and create the transaction/feed records atomically in Firestore.
- [x] Connect the Flutter app's send flow to that endpoint, with clear loading/error states; preserve existing Firebase Auth, profile, friendship, and safety behavior.
- [x] Update Firestore rules and emulator tests so clients cannot forge scores, transactions, feeds, or leaderboard score copies; add Node API tests and a minimal local run guide.
- [x] Correct MVP plan and project wiki claims that assume Cloud Functions or a Blaze upgrade are required for this backend path, and state that real-phone use needs the local server reachable while it is running.
- [ ] Security gate — PENDING
- [ ] Code review — PENDING
- [ ] Verification — PENDING

## Implementation Notes

The product spec and Slice 3 verification example say a send changes the
recipient's score. The approved plan said "both scores" in error; implementation
corrects that and leaves the sender score unchanged.

### Callers and contracts

- `app/lib/core/router/app_router.dart` and all screens importing
  `aura_routes.dart` keep the existing route constants; the shared contract only
  gains `sendAura`.
- `app/lib/features/home/presentation/home_screen.dart` still watches the
  existing `currentUserProvider` live stream; it gains a navigation button.
- `app/lib/features/friends/application/friends_providers.dart` supplies the
  same accepted-friend stream used by `FriendsScreen`; the send screen only
  reads it and does not alter friendship repository behavior.
- `app/lib/core/rules/aura_rules.dart` and `AuraUser.pointCaps` remain unchanged.
  The Node service mirrors the 500/-300 adult and 300/-150 minor caps.
- `app/lib/features/safety/data/account_deletion_service.dart` keeps its
  friendships → blocks → profile → Auth sequence but now calls the Node purge
  first, because only the server can remove copies in other users' feeds.

Contract before: no aura send path. After: a new authenticated local API path;
all existing signup, friend and settings callers retain their interfaces. No
caller requires migration. Rollback: remove the new `/send` route/button and
backend directory, then restore the Firestore rules to their earlier deny-all
for transaction/feed/rate-limit paths. Trigger: an observed regression in
signup, friendship or account safety checks.

### Known limits

- The local server has no always-on hosting and no production HTTPS endpoint.
- Account deletion needs the local API running. The purge is retriable and
  prevents concurrent aura sends, but availability still depends on the laptop.
- The built-in term filter is small; moderation review is needed before beta.
- Friend-circle fan-out, reactions and push remain their later slices.
- The Admin SDK's transitive `uuid` package has a moderate audit advisory;
  `npm audit --audit-level=high` exits 0.

## Security Gate

PENDING

## Code Review

PENDING

## Verification

PENDING

## Final Status: IN_PROGRESS
