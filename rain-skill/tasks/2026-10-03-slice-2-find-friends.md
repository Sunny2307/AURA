---
task-id: 2026-10-03-slice-2-find-friends
flow: FEATURE
status: BLOCKED-ON-DEVICE-VERIFICATION
started: 2026-10-03
completed: —
---

# Task: Slice 2 — Find friends (without phone numbers)

## Flow: FEATURE

**Done =** two accounts can find each other by exact `@username` or an invite
link, send and accept a friend request, and see each other in a friend list —
with emulator rules tests proving a third party cannot create, accept, read, or
tamper with someone else's friendship.

---

## Why this is not just "build what the plan says"

`aura-mvp-plan.md` §Slice 2 specifies contact permission → hash phone numbers
on-device → match against existing users. That design assumed phone + OTP login.
Slice 1 switched to email + password to stay on the Spark plan, so **no account
in the system has a phone number attached**. There is nothing to hash and nothing
to match against. The specced mechanism cannot be built as written.

## Constraints carried in from Slice 1

- **Spark plan — no Cloud Functions.** Anything the plan assumed a function would
  do must move to the client under security-rule supervision, or be deferred.
- `users/{uid}` is **self-readable only** (it holds `birthYear`, `isMinor`,
  privacy). Discovery needs a separate minimal public document.
- `friendCount` on `users/{uid}` is **client-immutable** in `firestore.rules`.
- `flutter test` cannot run on this machine — Windows Application Control blocks
  `flutter_tester.exe`. The emulator rules suite *does* run (54/54 green), so it
  carries the verification weight for this slice.

## Brainstorm

Answered by the user on 2026-10-03:

| Question | Answer |
|---|---|
| How do people find each other now that phone matching is dead? | **Exact `@username` search + shareable invite links** |
| Who maintains `friendCount` without Cloud Functions? | **Stop storing it; count the friend list on the client** |
| Is adding a friend mutual or one-sided? | **Request, then accept** |
| Should under-18 accounts be findable by strangers? | **Same as adults** |
| Where is a friendship stored? *(two approaches offered; user said "do the best thing by your side")* | **Approach 2 — one shared `friendships/{pairId}` document** |

### Rejected alternatives, and why

- **Mirrored `users/{uid}/friends/{friendUid}` subcollections** (what the plan's
  data model specifies). Rejected because accepting a request would mean writing
  into another user's document tree — the same cross-user write surface the user
  explicitly declined for `friendCount` — and because two documents that must
  agree can disagree. One shared document cannot half-exist.
  **Cost of this choice:** it departs from the data model in `aura-mvp-plan.md`,
  and Slice 6's leaderboard will read friendships by query rather than by
  subcollection listener. Recorded as a decision, not a drift.
- **Collecting phone numbers now** and building the original hashed matching.
  Rejected because it reintroduces PII for a minor-heavy audience and still needs
  Blaze for OTP, so the numbers would be unverified and spoofable.
- **Keeping `friendCount` via a rules-guarded cross-user `+/-1` write.** Rejected
  with the user — it would be the first write path into someone else's user
  document, for a number that can simply be counted.

### Deliberate exception to a locked decision

The plan's locked decisions say minors get stricter defaults. Choosing "minors
are discoverable the same as adults" is a **narrowing of that**, taken knowingly.
What still protects minors is untouched: rules-enforced leaderboard exclusion
(`leaderboardsAllowed`), tighter point caps via `AuraRules.pointCapsFor`, and
`isMinor` defaulting to true when data is missing. To be filed in `decisions.md`.

---

## Data model additions

### `publicProfiles/{uid}` — the minimal discovery document

```
publicProfiles/{uid}    username (immutable), photoUrl
```

- **Why it exists:** `usernames/{name}` already maps handle → uid and is
  world-readable, but it is `allow update: if false` by design, so a photo could
  never change there. Discovery needs one mutable, minimal, readable document.
- **Why `score` is NOT in it:** this document is client-written. A tampered
  client would put `score: 999999` in its own public profile and every search
  result would show the lie. Scores stay on `users/{uid}`, which the client
  cannot write. **Consequence: the Slice 2 friend list shows handle + photo, not
  scores.** Friend scores need either a server or a rules-gated read of
  `users/{uid}`, and the latter would expose `birthYear`/`isMinor`/privacy to
  friends — exactly what the 2026-10-03 decision avoided. Deferred to Slice 6,
  filed as an open question.
- Readable by any signed-in user. Writable only by its owner, `photoUrl` only.
- Created in the **same transaction** as `users/{uid}` and `usernames/{name}`,
  so the three cannot disagree. This extends the existing atomic-create pattern
  from two documents to three using `getAfter`, which the rules already use.

### `friendships/{pairId}` — one friendship, stored once

```
friendships/{pairId}    members [uidLow, uidHigh]  (sorted, exactly 2, distinct)
                        requestedBy  uid
                        status       'pending' | 'accepted'
                        createdAt    server timestamp
                        respondedAt  server timestamp | null
```

- `pairId` = the two uids sorted and joined with `_`. **The document id is the
  duplicate guard** — the same trick `usernames` uses. Two people requesting each
  other simultaneously collide on one id instead of creating two half-friendships.
- Rules:
  - `read` — only if `request.auth.uid in resource.data.members`.
  - `create` — requester is signed in, is a member, `status == 'pending'`,
    `requestedBy == request.auth.uid`, members sorted/distinct/size 2, `pairId`
    derived correctly from members, the other member's `publicProfiles` document
    exists, `createdAt == request.time`, `respondedAt == null`.
  - `update` — only the member who is **not** `requestedBy`, only
    `pending → accepted`, only `status` + `respondedAt` affected. Members,
    `requestedBy` and `createdAt` immutable.
  - `delete` — either member (covers decline, cancel, and unfriend with one rule).
- `firestore.indexes.json` gains a composite index on
  `members array-contains` + `status` + `createdAt desc`.

> **Two things I am relying on that need proving, not assuming:**
> 1. That a `where('members','array-contains', uid)` **list** query is accepted
>    against a rule written as `request.auth.uid in resource.data.members`. This
>    is the canonical Firestore pattern and I expect it to hold, but Step 2's
>    emulator tests must demonstrate it rather than take my word.
> 2. That Flutter's built-in deep linking handles an `aura://` custom scheme on
>    Android with only a manifest `intent-filter` and no extra package. If the
>    device test in Step 6 shows otherwise, the fallback is the `app_links`
>    package, and I will say so rather than quietly adding a dependency.

---

## Plan

Order is deliberate and mirrors Slice 1: **rules and their tests before any
client code.** Writing the client first means building against a permissive
backend and then being tempted to loosen the rules instead of fixing the client.

### Step 1 — Retire `friendCount` *(me)*
Touches `aura_user.dart`, a shared model — `defensive-editing` gets loaded first
and every caller traced before the edit.
- [x] Load `defensive-editing`; list every reader of `fieldFriendCount`
- [x] Remove `friendCount` from `AuraUser`, `newAccount`, `toCreateMap`,
      `fromMap`, `copyWith`
- [x] Remove it from `createFieldsAreExactly` and the `friendCount == 0` create
      check in `firestore.rules`
- [x] Update `aura_user_test.dart` and `rules.test.js` accordingly
- **Rollback:** restoring the field is a revert of this step's diff plus a rules
  redeploy.
- **Safe because** no production account exists yet — device verification never
  happened, so there is no stored data to migrate.
→ Verify: `flutter analyze` clean; full emulator suite still green

### Step 2 — Rules and rules tests for the two new collections *(me, then you review)*
- [x] `publicProfiles/{uid}` rules: signed-in read, owner-only write, `username`
      immutable after create, `photoUrl` the only mutable field
- [x] Extend the atomic account create to three documents via `getAfter`
- [x] `friendships/{pairId}` rules as specified above
- [x] `firestore.indexes.json` composite index
- [x] Tests proving a non-member **cannot** read, create, accept, or delete a
      friendship; that `requestedBy` cannot accept their own request; that
      `members`/`requestedBy` cannot be rewritten on accept; that a mismatched
      `pairId` is rejected; that a public profile cannot claim another handle;
      that the `array-contains` list query is actually permitted
→ Verify: `npm test` in `firestore-tests/` — full suite green, new cases named

### Step 3 — Repositories and providers *(me)*
- [x] `PublicProfileRepository` — `fetchByUsername`, `watchByUid`
- [x] `FriendshipRepository` — `request`, `accept`, `decline`, `cancel`,
      `unfriend`, `watchFriends`, `watchIncomingRequests`, `watchOutgoing`
- [x] Pure-Dart `pairId` derivation with its own unit test
- [x] Extend `createAccount` to write the public profile in the same transaction
- [x] Riverpod providers mirroring the Slice 1 shape, plus in-memory fakes in
      `test/support/fake_repositories.dart`
- [x] `friendCountProvider` derived from `watchFriends().length`
→ Verify: `flutter analyze` clean; `dart test` for the pure-Dart cases
  *(`dart test` sidesteps `flutter_tester.exe`; if it is blocked too, I will say
  so rather than claim coverage)*

### Step 4 — Find-a-friend UI *(me)*
- [x] Search screen: single handle field, offline `UsernameRules` shape check
      before any read, result card, explicit not-found state
- [x] States for every outcome: idle, searching, found, not found, already
      friends, request pending, yourself
- [x] 48dp minimum touch targets, primary action in the thumb zone
- [x] `const` constructors throughout; `ListView.builder` for every list
→ Verify: `flutter analyze` clean; widget tests written (see Step 7 on running)

### Step 5 — Friends list and requests UI *(me)*
- [x] Friends screen: accepted friends from a live listener, handle + photo,
      orb-free until scores exist
- [x] Incoming requests with Accept / Decline; outgoing shown as "Requested"
      with a cancel affordance
- [x] Empty state that tells a first user what to do rather than showing a void
- [x] Loading and error states with retry on both screens
- [x] Route registered in `app_router.dart` with a **per-route** auth guard, as
      that file's own comment anticipated for Slice 2
→ Verify: `flutter analyze` clean

### Step 6 — Invite links *(me)*
- [x] Share sheet producing text containing the handle and an `aura://u/<name>`
      link
- [x] GoRouter `/u/:username` route opening the profile preview with the same
      Add button as search
- [x] Android `intent-filter` for the `aura` scheme
- [x] Record honestly that an https link with an app-install fallback needs a
      registered domain and is deferred — no fake universal-link path
→ Verify: on device, tapping the link with the app installed opens the profile

### Step 7 — Gates and close *(me)*
- [x] `security-gate`
- [x] `post-task-review`
- [x] `verifying-completion` with pasted command output, not claims
- [x] Update `aura-mvp-plan.md`: rewrite the Slice 2 entry to match what was
      actually built, and record the data-model departure
- [x] File into `project-wiki`: `data-model`, `decisions`, `open-questions`,
      `features/friends`

## Things only you can do

- [ ] **Run the two-account test on a device** once Step 6 lands — this is the
      only way the end-to-end claim becomes true rather than inferred.
- [ ] *(Optional, unblocks a lot)* Decide whether to lift the Windows
      Application Control block on `flutter_tester.exe`, or accept that widget
      tests are written-but-unrun until they move to CI.

## Done When

- [x] Rules tests green, including every negative case in Step 2
- [x] `flutter analyze` clean and a debug APK builds
- [ ] Two accounts find each other by handle, request, accept, and both see the
      friendship — observed on a device, with output pasted
- [x] `friendCount` no longer exists as a stored field anywhere
- [x] The plan file tells the truth about what was deferred and why
- [x] `security-gate` and `post-task-review` both pass

## Open questions this slice deliberately leaves open

- How do friends see each other's **scores** without exposing `birthYear` /
  `isMinor`? Blocks the Slice 6 leaderboard. Likely needs Blaze.
- Blocking and reporting (`users/{uid}/blocks`) stay in Slice 9 — Slice 2 ships
  with unfriend as the only severing action.
- Slice 3's fanned-out feed assumed a Cloud Function. Still unsolved on Spark.

## Security Gate
Status: PASSED after remediation

Run as the 7-point FEATURE checklist plus an independent `security-auditor`
agent pass, which verified its findings against the emulator rather than
inferring them. It found two BLOCKING issues the checklist missed. Both are
fixed, and both now have regression tests.

### BLOCKING — found and fixed

- **An arbitrary `photoUrl` was a zero-interaction IP beacon.** The rules
  accepted any string, `publicProfiles` is readable by every signed-in user, and
  the friends screen renders a *pending* request's photo before any accept. So:
  set `photoUrl` to a server you control, send an unsolicited friend request to a
  handle, and the target's device hands over its IP, rough location, user agent
  and the exact moment they opened the app — against a user base that includes
  15-year-olds. Fixed by `isAllowedPhotoUrl`, which requires null while Cloud
  Storage does not exist, and carries the bucket-prefix form to use when it does.
  Six new rules tests.
- **The invite link never worked, and reached the dev screen.** `aura://u/<handle>`
  parses with `u` as the *authority*, so the path is `/<handle>` — and go_router
  matches on path alone. Every shared link would have dead-ended, and
  `aura://x/_design` opened `DesignCheckScreen`, which shipped in release builds
  unguarded. Fixed: the link is now `aura:///u/<handle>` (empty authority), the
  manifest filter drops `android:host`, `/_design` is compiled out under
  `kDebugMode`, and `/home` gained the guard. `test_unit/invite_link_test.dart`
  pins the parse, including an assertion that the two-slash form does *not* work,
  so nobody simplifies it back.

### Fixed from the WARNING list

- A signed-in principal with **no account** could send friend requests. A Firebase
  Auth token is obtainable straight from the REST endpoint without ever running
  the age gate, and such a request counted on the recipient's screen while
  rendering as nothing — invisible, undeclinable spam. Now `requesterExists()`.
- `privacy.whoCanSendAura: 'nobody'` was ignored for friend requests. Now checked
  via a rules-side `get()`, which grants the client no read.
- `_requireAccount` **failed open on error** — a revoked token read as "still
  loading" and sailed through. `SignupStatus.unknown` is split into `resolving`
  and `failed`; only `resolving` is let through.
- Raw `FirebaseException.toString()` was rendered on the friends screen, leaking
  the project id, query shape and a console URL. Replaced with user-facing copy.
  The error route no longer echoes the attacker-supplied URI, and the profile
  screen renders the *normalised* handle, not the raw path parameter.
- `fieldOverrides` now disables single-field indexes on `birthYear` and `isMinor`,
  so a future widened `list` cannot make `where('isMinor','==',true)` free.

### Logged, not fixed — address before any public beta

- **`usernames/{name}` is readable signed-out, so the user base is enumerable.**
  `list` is denied, but a dictionary attack on `get` yields a handle-to-uid map,
  and any throwaway account then reads every `publicProfiles/{uid}`. This is the
  deliberate slice 1 trade-off — handle availability is checked before the auth
  account exists — so the one-line fix is blocked by signup ordering. **Mitigation
  is App Check** (free on Spark) plus restricting the Android API key to the
  package and release SHA-1. Neither is code; both are console work.
- **No rate limit and no block list on friend requests.** Decline is a plain
  delete, so it is a reset rather than a signal: request, decline, request loops
  forever. `whoCanSendAura: 'nobody'` is the only lever today. A real
  `blocks/{...}` collection is Slice 9 and is the first thing to build there.
- Direct dependencies are one patch version behind. No known CVEs.

### Attacked and held

A non-member cannot create, read, accept, modify or delete a friendship.
Impersonation is closed by the three-way `getAfter` cycle — there is no sequence,
including delete-and-recreate, that yields a public profile claiming a handle you
do not own. No PII leak: `birthYear`, `isMinor`, privacy and email remain
reachable by nobody but the owner. No injection reaching a query — the handle is
validated offline, at both call sites, and independently in the rules, so the
client copy is not load-bearing. Minor protections from slice 1 survived
unchanged. Writes fail closed throughout: an unreadable status reads as `pending`,
never as consent. No hardcoded secrets.

## Code Review
Status: APPROVED

Four findings, all in my own code, all fixed:

- `friendCountProvider` was written and never read — dead on arrival, which is
  precisely the `orbTier` mistake this project already deleted once. Now drives a
  friend count on the home screen, so the derivation is actually exercised.
- `_Failed` still took an `error` it had stopped rendering.
- A friendship whose public profile would not resolve rendered as **nothing**
  while still counting in the section heading, leaving a "waiting on you (1)"
  badge the user could not clear. Now a dismissible `_Unresolved` row.
- `FriendTile`'s `Image.network` branch is unreachable now that the rules force
  `photoUrl` to null. Kept as the shape the real feature takes, but labelled, so
  it does not read as live code.

Passed: the three-document atomic create matches the rules exactly; every failure
has a named enum case with copy written at the screen rather than the repository;
48dp touch targets, loading and error states on every async surface, `const`
constructors, keyed list children; architecture follows the existing
data/application/presentation split and the slice 1 fake-repository pattern.

Suggestions logged: widget tests exist but have never run; the `_Unresolved` row
has no test.

## Verification
Status: PARTIAL — everything automatable here is green; device verification pending

Observed, from the final run:

```
flutter analyze                  -> No issues found!           (exit 0)
dart test test_unit              -> 22/22 All tests passed!    (exit 0)
npm test (rules, emulator)       -> tests 102 / pass 102 / fail 0
npm audit --audit-level=high     -> found 0 vulnerabilities    (exit 0)
flutter build apk --debug        -> Built app-debug.apk        (exit 0)
firebase deploy --only firestore -> rules released, indexes deployed to aura-d68c3
```

**124 tests execute on this machine**, up from 54 at the start of the task.

Not verified, and not claimed:

- **The two-account device run.** Nothing here proves a real phone completes
  request then accept end to end. That is the claim still outstanding.
- **Widget tests** (`test/features/friends_flow_test.dart`) have never executed.
  `flutter test` was re-run and re-confirmed blocked — the exact error is
  `An Application Control policy has blocked this file ... flutter_tester.exe`.
  Written for CI, cited as evidence by nothing.
- **The `aura:///u/<handle>` link opening the app on a device.** The URI *parse*
  is now pinned by a test, which is what was actually wrong; whether Android
  routes the intent still needs a device.

### Environment findings worth keeping

- The Firebase CLI needs JDK 17 on **PATH**, not merely in `JAVA_HOME` — `java`
  resolves to Oracle Java 8 here and the emulator refuses to start. Prepend
  `$JAVA_HOME/bin` before `npm test`.
- `dart test` is a working escape hatch from the `flutter_tester.exe` block for
  anything Flutter-free. This is why `AuraRoutes` was split out of
  `app_router.dart` into `aura_routes.dart` — the constants were untestable only
  because the file they lived in imported every screen.

## Final Status: BLOCKED — awaiting two-account device verification
