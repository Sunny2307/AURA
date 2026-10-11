---
task-id: 2026-10-03-slice-9-safety-surfaces
flow: FEATURE
status: BLOCKED-ON-DEVICE-VERIFICATION
started: 2026-10-03
completed: —
---

# Task: Slice 9 — Privacy and safety surfaces

## Flow: FEATURE

**Done =** a user can block someone (which severs the friendship and silently
prevents further contact), report someone, change their privacy settings, see
and undo their blocks, and permanently delete their account — with emulator
rules tests proving none of it can be done to or on behalf of anyone else.

---

## Why this is being built out of order

The plan runs Slice 9 last. It is being pulled forward because:

1. **Slices 3–7 are hard-blocked on the Blaze plan.** Slice 3 specifies
   `onTransactionCreate` to update both scores atomically and fan out feeds — a
   Cloud Function, which Spark does not have. Slices 4, 5, 6 and 7 all depend on
   it or on the same server. Slice 9 and Slice 8 are the only remaining slices
   buildable on Spark.
2. **The slice 2 security review named the block list as the single most
   important thing to build next.** Friend requests today have no block and no
   rate limit, and decline is a plain delete — so it is a *reset*, not a signal.
   Request → decline → request loops forever against any handle, at an audience
   that includes 15-year-olds.

## What Slice 9 promises, and what is actually buildable now

`aura-mvp-plan.md` Slice 9 and spec §10 between them promise eight things. Three
presume transactions exist, and transactions are Slice 3.

| §10 requirement | This task |
|---|---|
| Blocking, fully silent | ✅ built |
| Settings screen (§5.11) | ✅ built, minus notification toggles |
| Opt out of public visibility | ✅ built |
| Account deletion | ✅ built |
| Reporting | ✅ a *user* can be reported; a *transaction* cannot, there are none |
| Minor defaults | ✅ already done in slice 1, rules-enforced, untouched here |
| Word filter on custom text | ❌ Slice 3 — no custom text exists yet |
| Rate limit on repeated negatives | ❌ Slice 3 — no negatives exist yet |

## The state on the ground

Checked directly, not assumed:

| Thing | State |
|---|---|
| Settings screen | ❌ does not exist — no `lib/features/settings/` |
| `UserRepository` privacy writes | ❌ no update method; the rules permit it, the client has no way to call it |
| `users` / `publicProfiles` / `usernames` delete rules | ❌ all `allow delete: if false` |
| `friendships` delete | ✅ either member |
| `AuthRepository.deleteCurrentUser` | ⚠️ exists, **called by nothing but the fake** |
| `blocks` collection | ❌ does not exist |
| `reports` collection | ❌ does not exist |

> ⚠️ **A trap worth naming before anything calls it.** `deleteCurrentUser`
> deletes the *Firebase Auth* account only. Every Firestore delete rule is
> `false`, so calling it today would strand `users/{uid}`,
> `publicProfiles/{uid}` and the permanent `usernames/{name}` claim with no
> account behind them and no way to ever remove them. It is unused, which is the
> only reason this is not already a live bug. Step 5 makes it safe to call.

## Brainstorm

Answered by the user on 2026-10-03:

| Question | Answer |
|---|---|
| How silent should a block be? | **Block removes the friendship** — the blocked person sees you gone, indistinguishable from being unfriended |
| What should account deletion do? | **Full delete, handle stays burned** — the `usernames` claim survives as a tombstone |
| What should reporting do, with nobody reviewing? | **File the report and auto-block**, in one commit |
| Notification toggles in settings? | **Leave them out** — push is Slice 7 and Blaze-blocked |

### Rejected alternatives, and why

- **Truly silent blocking** (friendship document survives, suppressed on one
  side). Closer to the letter of §10, but it stores a friendship that is a lie
  on one side — the same "two documents that must agree" problem the slice 2
  design was built to avoid. Rejected with the user.
- **Releasing the handle on delete.** Cleanest "nothing of mine remains", but it
  breaks the never-reassigned invariant from slice 1 and would let someone squat
  a churned friend's name, with old mentions silently re-pointing at a different
  person. Rejected: personal data goes, the reserved string stays.
- **Deferring deletion to Blaze.** Lower risk, but it would ship a beta to
  minors with no way to leave. Rejected.
- **Report without blocking.** Nobody is reviewing the queue, so a report that
  does nothing visible is worse than no report button — it implies a protection
  that does not exist.
- **Top-level `blocks/{blockerUid_blockedUid}`** instead of a subcollection.
  Equivalent security, but listing your own blocks would need a query plus a
  composite index, where the subcollection gets a scoped listener for free. The
  slice 2 reason for preferring a top-level collection does not apply here:
  friendships needed it because *accepting* writes on behalf of two people,
  whereas a block is written by the blocker into their own tree only.

### A limitation that cannot be designed away on Spark

When a blocked person tries to re-request, the rules deny the write and their
client receives an error. Generic copy makes that indistinguishable from a
network failure, which is as silent as client-side enforcement gets — but
someone comparing behaviour across two accounts could infer it. Genuinely
undetectable blocking requires a server that can accept the write and quietly
discard it. Recorded as an open question rather than papered over.

---

## Data model additions

### `users/{uid}/blocks/{blockedUid}` — who you have blocked

```
users/{uid}/blocks/{blockedUid}    createdAt
```

- A subcollection under the **blocker**, matching the plan's data model. The
  document id is the blocked uid, so "have I blocked them" is a document read.
- **Readable and writable by the owner only.** Nobody can see who has blocked
  them — that is what makes it silent.
- The friendship create rule reads it with `exists()`, which inside a rule
  bypasses the read rules and leaks nothing to the client: only the boolean
  outcome reaches anyone.
- Blocking is **two-way in effect**: the friendship rule checks blocks in both
  directions, so a blocked person cannot request the blocker *and* the blocker
  does not have to unblock to be left alone.

### `reports/{reportId}` — filed, not reviewed

```
reports/{reportId}    reporterUid, reportedUid, reason, createdAt
```

- `create` only, by a signed-in user, with `reporterUid == request.auth.uid`.
- **`read` is denied to everyone**, including the reporter. There is no
  moderation UI and no reviewer in the app; these are read from the Firebase
  console. A reports collection any client could read would be a list of
  accusations about named people.
- A report requires its matching block to land in the same commit, enforced with
  `existsAfter` — the same atomicity trick the account create uses. Reporting
  and blocking cannot come apart.
- `reportedUid` is not validated against existence on purpose: a report about an
  account that has since deleted itself is still worth having.

### Deletion rules

`users/{uid}` and `publicProfiles/{uid}` gain `allow delete: if isSelf(uid)`,
each requiring the other to be gone after the commit via `!existsAfter(...)` —
the mirror image of the create cycle, so the two halves cannot come apart in
either direction.

`usernames/{name}` keeps `allow delete: if false`. That is the tombstone.

---

## Plan

Same order as slice 2, for the same reason: **rules and their tests before any
client code.** Building the client first means building against a permissive
backend and then being tempted to loosen the rules rather than fix the client.

### Step 1 — Block rules and tests *(me, then you review)*
- [x] `users/{uid}/blocks/{blockedUid}` rules: owner-only read, create and
      delete; `createdAt == request.time`; no other fields; cannot block
      yourself
- [x] Friendship `create` checks blocks **in both directions** and denies
- [x] Tests: a stranger cannot read or write someone's block list; a blocked
      user cannot request the blocker; the blocker cannot be requested by them
      either; unblocking restores the ability to request; blocking yourself
      fails
→ Verify: `npm test` in `firestore-tests/` — full suite green, new cases named

### Step 2 — Report rules and tests *(me)*
- [x] `reports/{reportId}` rules as specified above, including `read: if false`
- [x] A report without its matching block in the same commit is rejected
- [x] Tests: cannot file a report as somebody else; cannot read any report, own
      or otherwise; cannot report without blocking
→ Verify: `npm test` green

### Step 3 — Deletion rules and tests *(me)*
- [x] `allow delete: if isSelf(uid)` on `users` and `publicProfiles`, each
      requiring the other to be absent after the commit
- [x] `usernames` stays `allow delete: if false` — assert this with a test, so
      the tombstone is a tested invariant rather than an omission
- [x] Tests: cannot delete someone else's account; cannot delete half an account;
      cannot delete the handle claim; a full three-part delete succeeds
→ Verify: `npm test` green

### Step 4 — Repositories and providers *(me)*
- [x] `BlockRepository` — `block`, `unblock`, `watchBlocked`, `isBlocked`
- [x] `ReportRepository` — `report`, which writes the report and the block in
      one batch
- [x] `UserRepository.updatePrivacy` — the missing write; the rules have always
      allowed it and no client method existed
- [x] `AccountDeletionService` — batches the friendship deletes, the public
      profile and the user document, then deletes the auth account **last**, so
      a failure leaves a recoverable signed-in state rather than an orphan
- [x] Riverpod providers plus in-memory fakes, matching the slice 1/2 shape
- [x] Pure-Dart tests under `test_unit/` for anything Flutter-free
→ Verify: `flutter analyze` clean; `dart test test_unit` green

### Step 5 — Settings screen *(me)*
- [x] `lib/features/settings/` — who can send you aura, leaderboard visibility
- [x] Minor accounts: leaderboard toggle visibly locked off, not silently
      ignored, with a line saying why
- [x] Blocked list with unblock, reached from settings
- [x] Delete account behind a typed confirmation, with honest copy about what
      survives: the handle is never reissued
- [x] No notification toggles — push is Slice 7
- [x] 48dp targets, loading and error states, destructive actions in a
      confirm dialog and coloured as destructive
→ Verify: `flutter analyze` clean; widget tests written (unrunnable here)

### Step 6 — Block and report entry points *(me)*
- [x] Overflow action on a friend row and on the profile preview screen
- [x] Blocking an existing friend deletes the friendship in the same batch
- [x] Report sheet with a short reason list, filing report + block together
- [x] Generic failure copy on a denied request, so a block is not announced
→ Verify: `flutter analyze` clean; debug APK builds

### Step 7 — Gates and close *(me)*
- [x] `security-gate`, including an independent `security-auditor` pass — the
      slice 2 one found two blockers the checklist missed
- [x] `post-task-review`
- [x] `verifying-completion` with pasted output, not claims
- [x] Update `aura-mvp-plan.md`: mark Slice 9 partially done, record what is
      deferred to Slice 3 and why
- [x] File into `project-wiki`: `data-model`, `decisions`, `open-questions`,
      `features/safety`

## Things only you can do

- [ ] **Device-verify this slice** alongside the outstanding Slice 1 and 2
      checks: block someone and confirm they vanish; delete a test account and
      confirm the documents are gone from the console while the handle stays
      claimed.
- [ ] *(Still open from slice 2)* App Check and Android API key restriction, to
      close the handle-enumeration hole. Console work, not code.

## Done When

- [x] Rules tests green, including every negative case in Steps 1–3
- [x] `flutter analyze` clean, `dart test test_unit` green, debug APK builds
- [x] A blocked user cannot reach the blocker in any direction
- [x] A report cannot be filed without its block, and no client can read reports
- [x] An account can delete itself completely; the handle stays claimed forever
- [x] `security-gate` and `post-task-review` both pass

## Open questions this slice deliberately leaves open

- Truly undetectable blocking needs a server. See the limitation above.
- Nobody reviews `reports/`. Before a public beta that needs either a person or
  a console workflow, or the button is a promise the product does not keep.
- Word filtering and negative-send rate limits remain Slice 3 work, and Slice 3
  remains Blaze-blocked.

## Deviations from the plan as approved

Both flagged while they were made, neither silent:

- **`BlockRepository` + `ReportRepository` became one `SafetyRepository`.** The
  rules require a report and its block in the same commit, so two repositories
  would have meant one reaching into the other's collection to assemble a shared
  batch. They are one concern.
- **`AccountDeletionService` became an interface.** It was a concrete class,
  which made it the only type under `data/` that could not be faked — and the
  delete screen untestable.

## Security Gate
Status: PASSED after remediation

The 7-point FEATURE checklist plus an independent `security-auditor` pass that
verified its findings against the emulator. It found one BLOCKING issue and three
WARNINGs. All four are fixed; every one has a regression test.

### BLOCKING — the safety feature did not work for the case it exists for

`FirestoreSafetyRepository._addBlock` unconditionally batched a friendship
delete alongside the block. Deleting a friendship that does not exist is a no-op
in the *datastore* — but not in the *rules engine*, where `resource` is null and
`request.auth.uid in resource.data.members` raises an evaluation error, which
denies. A batch is atomic, so the block and the report went down with it.

**Block and report therefore failed 100% of the time against anyone you were not
already friends with** — the stranger who reached you through an invite link,
which is precisely the case the safety menu was built for, aimed at a 15+
audience. A report about a non-friend could never be filed at all, so the
console-only queue would have under-reported exactly the incidents it exists to
capture.

It shipped behind **132 green tests** because every one of them exercised the
*pieces* of that write — the block document alone, the report plus block — and
none committed the batch the client actually sends. There is now a suite that
does, named `the batch the client actually sends`, and it was RED before the fix.

The fix derives membership from the document id when `resource` is null:

```
allow delete: if isSignedIn()
              && (resource == null
                    ? request.auth.uid in pairId.split('_')
                    : request.auth.uid in resource.data.members);
```

Sound because `pairIdMatches` guarantees the id is the two sorted uids and
Firebase uids contain no underscores. Deliberately **not** an existence oracle:
the tempting `resource == null || ...` form would let anyone probe any uid pair
and learn whether two people are friends. Here a non-member is denied on both
branches, so the outcomes are indistinguishable. Two tests pin that.

### Fixed from the WARNING list

- **Ghost tokens could write unbounded blocks and reports.** A Firebase Auth
  token is obtainable from the REST signup endpoint without ever running the age
  gate. `friendships` already guarded against this; blocks and reports did not —
  leaving an unthrottled write path into a *shared, project-wide* daily quota,
  enough to deny service to every real user for a day while burying the report
  queue under fabricated rows. Now `accountExists()`, promoted to a top-level
  helper and used by all three collections.
- **A block did not stop an in-flight accept.** `neitherHasBlockedTheOther` was
  checked on friendship `create` but not `update`, so a block written on its own
  over REST — or racing an accept already in flight — left someone able to
  become a friend of a person who had just blocked them. Now checked on both.
- **A deletion race could strand a friendship.** The first friendship sweep works
  from a snapshot, and `targetExists()` keeps passing for three more round trips,
  so a request landing in that window outlived the account it named. A second,
  terminal sweep now runs after the profile pair is gone.

### Logged, not fixed

- **No cap on blocks or reports per user.** `accountExists()` closes the ghost
  vector, but a real account can still write at volume. There is no per-user
  throttle possible on Spark without a Cloud Function. Cheapest honest
  mitigation is a Firestore budget alert; recorded as residual beta risk.
- **A block deleted after filing leaves a report without a standing block.** The
  `existsAfter` coupling is checked at commit only. So the rule guarantees the UI
  cannot *offer* a report without a block, not that a filed report stays backed
  by one. Worth knowing before the queue is ever triaged.
- **Handle enumeration** remains open from slice 2. Needs App Check.

### Attacked and held

Block lists are unreadable and un-enumerable — including via `collectionGroup`,
which `rules_version 2` excludes from the subcollection match, and which is
load-bearing enough to deserve its permanent test. No acting on another's
behalf anywhere. Reports are read-denied to everyone including their author, and
cannot be altered or withdrawn. Deletion authorisation holds in both directions,
neither half can go alone, and the handle cannot be freed or re-claimed by
another uid. A minor cannot enable leaderboards — not via a full map write, and
not via a dotted-path partial update either, because `leaderboardsAllowed` reads
the *stored* `isMinor`. The three new routes are guarded and fail closed. No PII,
no raw errors, no secrets.

## Code Review
Status: APPROVED

One finding in my own code, fixed:

- **A row that could not be measured.** `accept` + `decline` + the safety
  overflow in a `ListTile.trailing` is roughly 236dp of controls; on a 360dp
  phone that squeezes the handle — the one thing the row exists to show — to
  almost nothing, and narrower screens can overflow outright. `flutter test`
  cannot run here, so this was unverifiable by any means available. Shipping an
  unverifiable layout was the wrong call, so decline moved into the overflow menu
  beside block and report, which reads better regardless: they are all ways to
  make somebody go away. `FriendTile` also now truncates rather than wraps.

Passed: the rules and the client agree on every safety invariant, including the
ones the client enforces only for better copy (self-block, self-report). Every
failure maps a closed enum to fixed copy written at the screen. The report
vocabulary is an enum whose wire values are bounded by construction and pinned to
the rules' 40-character cap by a test that runs. Architecture follows the
existing data/application/presentation split.

Suggestions logged: `FakeSafetyRepository` does not mirror the new
`accountExists` rule the way `FakeUserRepository` mirrors the minor/leaderboard
one; `_Unresolved` rows carry no safety menu; widget tests remain unexecuted.

## Verification
Status: PARTIAL — everything automatable here is green; device verification pending

Observed, from the final run:

```
flutter analyze                  -> No issues found!           (exit 0)
dart test test_unit              -> 27/27 All tests passed!    (exit 0)
npm test (rules, emulator)       -> tests 143 / pass 143 / fail 0
npm audit --audit-level=high     -> found 0 vulnerabilities    (exit 0)
flutter build apk --debug        -> Built app-debug.apk        (exit 0)
firebase deploy --only firestore -> rules released, indexes deployed to aura-d68c3
```

**170 tests execute on this machine**, up from 124 at the start of this task.

Not verified, and not claimed:

- **Nothing has been run on a device.** Slices 1, 2 and 9 now all carry
  unverified end-to-end claims. This is the largest outstanding risk in the
  project and it grows with every slice built on top.
- **Widget tests** (`test/features/safety_flow_test.dart`, 14 cases) have never
  executed — `flutter_tester.exe` is blocked by Windows Application Control.
  Written for CI, cited as evidence by nothing.
- **The deletion race fix** is reasoned and the second sweep is terminal by
  construction, but the race itself was never reproduced here.

## Final Status: BLOCKED — awaiting device verification
