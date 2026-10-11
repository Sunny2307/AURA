# Safety — Slice 9

Blocking, reporting, privacy settings and account deletion. Built 2026-10-03,
**out of order**, because Slices 3–7 are Blaze-blocked and the Slice 2 security
review named the block list as the most important thing to build next.

See [[data-model]] for the collections and [[decisions]] for the choices.

## Blocking

A block severs the friendship and prevents contact **in both directions**.

The two-way check is deliberate: if only "has the target blocked me" were
checked, a blocker could still re-request the person they blocked, so blocking
would end only half the relationship.

**What makes it silent** is one line — `users/{uid}/blocks/{blockedUid}` is
readable by its owner and nobody else. The blocked person has no document to
read, no query that returns one, and no way to distinguish a block from a
dropped connection. The friendship rule reaches in with `exists()`, which inside
a rule bypasses the read rules and hands only a boolean to the evaluator.

The limitation, stated rather than hidden: a denied write still *is* a denied
write. Someone comparing behaviour across two accounts could infer a block.
Genuinely undetectable blocking needs a server that can accept the write and
quietly discard it.

## Reporting

`reports/{reportId}` is **read-denied to every client, including its author** —
these are read from the Firebase console. A readable reports collection is a
list of accusations about named people.

A report requires its matching block in the same commit, enforced with
`existsAfter`. Nothing reviews the queue yet, so the block is the only thing
that actually protects the reporter; coupling them server-side is what stops the
UI drifting into a report button that quietly does nothing. The report sheet
says so in as many words.

Reasons are a closed enum (`ReportReason`), not free text — free text about a
named person would itself be the unmoderated channel the report form exists to
address, and it would be uncountable from a console.

## Account deletion

Goes: every friendship, your own block list, `publicProfiles/{uid}`,
`users/{uid}`, then the Firebase Auth account.

Stays: `usernames/{name}`, forever. See [[decisions]].

**Order is load-bearing.** Auth is last, because deleting it first would leave a
signed-out caller holding Firestore documents only *they* were allowed to
remove. Failing partway leaves someone signed in and recoverable.

Friendships are swept **twice**. The first sweep works from a `.get()` snapshot,
and `targetExists()` keeps passing for three more round trips, so a request
landing in that window would outlive the account it named. The second sweep is
terminal rather than another race: by then the public profile is gone and no new
friendship can be created at all.

## The mistake worth remembering

Block and report **did not work against strangers at all**, and shipped behind
132 green tests.

`_addBlock` batched a friendship delete alongside the block. Deleting an absent
document is a no-op in the datastore but *not* in the rules engine, where
`resource` is null and `request.auth.uid in resource.data.members` raises an
evaluation error. A batch is atomic, so the block died with it. The feature
worked only against existing friends — never against the stranger from an invite
link, which is the case it was built for.

Every test exercised the *pieces* of that write; none committed the batch the
client actually sends. **That is the lesson, not the null check:** a rules suite
that tests document-at-a-time can be entirely green while the client's real
transaction is impossible. There is now a suite called `the batch the client
actually sends`.

Three more closed at the same time: ghost Auth tokens (no account, no age gate)
could write unbounded blocks and reports into the shared project quota; a block
did not stop an in-flight accept; and the deletion race above.

## Key files

| Path | What |
|---|---|
| `app/lib/core/models/report_reason.dart` | The closed reason vocabulary |
| `app/lib/features/safety/data/safety_repository.dart` | Blocks + reports, one repo because the rules demand one commit |
| `app/lib/features/safety/data/account_deletion_service.dart` | The unwind |
| `app/lib/features/safety/presentation/safety_menu.dart` | The block/report overflow |
| `app/lib/features/settings/presentation/` | Settings, blocked list, delete |
| `app/firestore.rules` | `blocks`, `reports`, deletion, `accountExists` |

## Verification status

- ✅ 143 emulator rules tests (`npm test` in `app/firestore-tests/`)
- ✅ 27 pure-Dart tests (`dart test test_unit`)
- ⛔ 14 widget tests at `app/test/features/safety_flow_test.dart`, **never
  executed** — `flutter_tester.exe` is blocked. See [[open-questions]].
- ⛔ No device run. Slices 1, 2 and 9 all carry unverified end-to-end claims.

## Sources

- Task: `docs/rain-skill/tasks/2026-10-03-slice-9-safety-surfaces.md`
- Related: [[features/friends]], [[data-model]], [[decisions]]
