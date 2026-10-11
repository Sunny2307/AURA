# Data Model

## Collections

### `users/{uid}` — the private profile
Stores username, optional photo URL, score, birth year, minor state, privacy
defaults, and creation time.

**Self-readable only**, including to friends, because it holds age and privacy
state. Clients may change only their own photo URL and allowed privacy values.
Score, username, birth year and minor state are immutable to clients.

A consequence worth stating plainly: **friends cannot read each other's scores.**
See [[open-questions]].

### `usernames/{username}` — uniqueness
Maps a handle to its owning uid. Claimable once, never reassigned, never
released. The document id is the uniqueness guarantee — Firestore has no unique
index. Readable while signed out so the signup availability check can run before
an account exists; `list` is denied.

### `publicProfiles/{uid}` — discovery *(slice 2)*
Username and photo URL, nothing else. The only shape another user can read before
you are friends.

It exists because `usernames/{name}` is permanently immutable by design, so a
changed photo could never be reflected there. **It deliberately contains no
score**: the document is client-written, so anything in it is something a
decompiled client can lie about. A forged score would appear in every search
result as if real. The handle cannot be forged — the create rule ties it to
`users/{uid}.username`, which is tied to the permanent handle claim.

Readable by any signed-in user; `list` denied, so the user base cannot be
enumerated.

### `friendships/{pairId}` — one friendship, one document *(slice 2)*
`members[2]` (sorted), `requestedBy`, `status` (`pending` | `accepted`),
`createdAt`, `respondedAt`.

`pairId` is the two uids sorted and joined with `_`. The document id is derived
from the contents and the rules re-derive and check it, which means two people
requesting each other simultaneously collide on one document instead of creating
two competing friendships. Same trick as `usernames`.

Readable and deletable by either member. Creatable only by a member, only as
`pending`, only with `requestedBy` equal to the caller. Acceptable only by the
member who is **not** `requestedBy` — that single clause is the consent model.

Decline, cancel and unfriend are all a delete. There is no `declined` state,
which would be read by nobody and would tell a sender they were rejected.

### `users/{uid}/blocks/{blockedUid}` — who you have blocked *(slice 9)*
`createdAt` only. A subcollection under the **blocker**, so the document id is
the blocked uid and "have I blocked them" is a document read.

**Readable by the owner and nobody else.** That single rule is the silence
guarantee — the blocked person has no document to read and no query that returns
one. `collectionGroup('blocks')` is denied for everyone including owners, which
`rules_version 2` gives us because a subcollection `match` does not apply at
collection-group scope.

Checked **in both directions** on friendship create and update: a block ends the
whole relationship, not half of it.

Subcollections are not removed when their parent document is deleted, so account
deletion sweeps this explicitly.

### `reports/{reportId}` — filed, never reviewed by a client *(slice 9)*
`reporterUid`, `reportedUid`, `reason`, `createdAt`.

**`read` is denied to everyone, including the reporter.** Read from the Firebase
console. `reason` comes from a closed enum and is capped at 40 characters
server-side. A report requires its matching block in the same commit.

### `transactions/{senderUid}_{idempotencyKey}` — trusted aura send *(slice 3)*

Stores sender/recipient uids, signed points, reason/chip, visibility, timestamp,
reactions, a request fingerprint and the recipient score after the send. Only
the two participants may read one by ID; all mobile writes and list queries are
denied. The Node.js Admin SDK writes the document in the score transaction.

### `users/{uid}/feed/{txId}` — participant feed copies *(slice 3)*

The same transaction writes a copy for sender and recipient. Only the owner may
read; clients cannot write. Friends-circle fan-out remains for Slice 5.

### `rateLimits/{key}` — server-only send counters *(slice 3)*

Rolling timestamp arrays for the sender's hourly total and sender/recipient
negative total. No mobile client may read or write these documents.

## Enforced invariants

1. **Account creation is atomic across three documents** — `users/{uid}`,
   `usernames/{name}` and `publicProfiles/{uid}` each require the other two to
   exist after the commit, via `getAfter`. No piece can be created alone.
2. **The client never raises its own score.** Pinned to 1000 on create,
   immutable after.
3. **A handle is never reassigned.**
4. **`isMinor` and `birthYear` are immutable after create**, and `isMinor` must
   agree with the birth year the account claims.
5. **A minor can never appear on a public leaderboard** — checked on create and
   on every update.
6. **Nobody can write into another user's document tree.** There is no such rule
   anywhere in the file, which is why friendships are one shared document.
7. **Every client-writable collection requires a finished account.**
   `accountExists(uid)` — a Firebase Auth token is not an Aura account, and a
   holder of one never passed the age gate.
8. **Account deletion takes both halves or neither.** `users/{uid}` and
   `publicProfiles/{uid}` each require the other to be absent after the commit —
   `existsAfter` run backwards. `usernames/{name}` can never be deleted.
9. **Only the Node.js API changes scores after signup.** It checks authorization
   and limits and updates the recipient score and records in one transaction.

Account deletion first calls the Node.js purge endpoint. It marks the profile
`deleting`, which blocks in-flight and new sends, then removes transactions,
feed copies in both participants' trees and rate-limit records. The old client
flow then removes friendships, blocks, the profile pair and Auth identity.
The local API must be running for deletion to finish.

## What is NOT stored

`friendCount` was removed in slice 2. It was pinned to 0 and only a Cloud
Function could legally move it, so on the Spark plan nothing ever did — a stored
number that could only be wrong. It is counted from `friendships` instead. Same
reasoning that removed `orbTier` in slice 1.

## Departure from the MVP plan

`aura-mvp-plan.md` specifies mirrored `users/{uid}/friends/{friendUid}`
subcollections. Slice 2 replaced that with the single shared document above. See
[[decisions]] for why, and the slice 2 task record for the rejected alternatives.

## Sources

- Code: `app/firestore.rules`, `app/firestore.indexes.json`,
  `app/lib/core/models/aura_user.dart`, `app/lib/core/models/friendship.dart`,
  `app/lib/core/models/public_profile.dart`
- Tests: `app/firestore-tests/rules.test.js` (143 cases),
  `app/test_unit/friendship_test.dart`
- Task: `docs/rain-skill/tasks/2026-10-03-slice-2-find-friends.md`
