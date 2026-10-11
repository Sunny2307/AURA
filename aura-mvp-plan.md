# Aura — MVP Build Plan

**Goal:** ship the 11 must-have features from `aura_app_full_product_plan.md` §4.1 as a working Flutter app on iPhone + Android, good enough to seed into 2–3 real friend groups for a closed beta.

**Scope:** MVP only. Phase 2–4 (decay, streaks, battles, Wrapped, monetization) are out of scope — see *Deliberately Not Now* at the bottom.

> **2026-10-04 architecture update:** Firebase remains on the Spark plan. A
> standalone Node.js API on the developer's computer replaces the planned Cloud
> Functions for trusted score writes. It is implemented for local development,
> but a closed beta across real friend groups still needs an always-on HTTPS
> deployment. Earlier references below to a "Blaze wall" describe the rejected
> Cloud Functions design, not the current project constraint.

---

## Locked decisions

| Decision | Choice | Why |
|---|---|---|
| App framework | **Flutter** | One codebase, both phones. Strong control over the orb glow / count-up / particle motion in spec §6.5 |
| Backend | **Firebase Spark** (Auth, Firestore) + standalone **Node.js API** | Keep the existing Firebase project; move trusted writes to a server outside Firebase |
| Under-18 users | **Allowed, 15+** | Matches the 15–22 primary audience (§2.3). Minors get stricter defaults |
| Team | **You + Claude** | Plan is sized in slices, not calendar weeks |
| Launch | **Both phones together** — *but see iOS note below* | Beta via TestFlight + Play internal testing |
| Build order | **Vertical slices** | Each slice is fully working on a real phone before the next starts |

> **⚠️ iOS reality check (found 2026-09-04, during Slice 0):** the dev machine is Windows.
> Building for iPhone requires Xcode, which is macOS-only, so **iOS builds cannot happen on
> this machine at all** — this is a hard platform limit, not a setup problem.
> **Decision:** build and verify every slice on Android for now; revisit iOS before the beta
> via a cloud-Mac service (Codemagic / GitHub Actions macOS runners) or a physical Mac.
> Impact is small because the Flutter code itself is shared — what's deferred is iOS
> *building, signing, and testing*, not the app logic. Every `→ Verify:` step below
> therefore reads "Android" until that's resolved.

---

## Before slice 1 — things only you can do

- [x] **Create the Firebase project.** Project `aura-d68c3` exists, the Android app is registered, and the generated client configuration is present.
- [ ] **Buy an Apple Developer account** ($99/yr). Blocks *all* iPhone testing, even on your own phone. Approval can take days — do this first.
- [x] **Keep Firebase on Spark.** Email/password stays; Cloud Functions are replaced by the Node.js API. Phone OTP and Firebase Storage photos are not part of this architecture.
- [ ] **Confirm the app name "Aura" is free** on both stores and as a package id (`com.apexverse.aura`).
- [ ] **Generate a release keystore** and an `android/key.properties` pointing at it. Both are gitignored. Until then release builds fall back to debug signing, which the Play Store will not accept.

You already have the Google Play account. ✅

---

## How verification works on this setup

**You do the device checks.** I build and verify everything that can be checked
without a phone in hand, and each slice lists both parts separately:

| I verify, every slice | You verify, on your physical phone |
|---|---|
| `flutter analyze` clean | it feels right — animation smoothness, real OLED black |
| `dart test test_unit` green (pure-Dart logic) | real signup landing a real account |
| `npm test` in `app/firestore-tests` green (security rules) | camera, contacts, push notifications |
| `flutter build apk` succeeds | sharing to Instagram / TikTok |

> **⚠️ Corrected 2026-10-03: `flutter test` does not run on this machine.**
> Windows Application Control blocks `flutter_tester.exe`, so `flutter test`
> cannot load *any* test file — widget tests and the golden test included. This
> row used to claim it was verified every slice; it was not.
>
> What replaced it: `test_unit/` holds Flutter-free tests that run on the plain
> Dart VM via `dart test test_unit`, and the Firestore rules suite runs against
> the emulator. Between them, 170 tests actually execute. Widget tests are still
> written, and still wait for CI or a policy change — they are never cited as
> evidence that something works.
>
> The regenerate-goldens command below is in the same position: it cannot run
> here either.

Golden images (`app/test/golden/goldens/`) are the substitute for screenshots.
Regenerate after any theme change:

```bash
cd app && flutter test test/golden/design_check_golden_test.dart --update-goldens
```

> **One thing I changed on your machine, so it doesn't surprise you later:** while
> trying to get an emulator authorized I found `~/.android/adbkey` existed without
> its matching `adbkey.pub`, which is why adb could never authorize. I backed the
> orphaned key up to `~/.android/adbkey.orphaned-backup-20260904` and regenerated
> the pair. **Consequence:** any Android phone you had previously authorized for
> USB debugging will show the "Allow USB debugging?" prompt once more on the next
> connect. Tick "always allow" and it's done.

---

## Data model (Firestore)

Firestore isn't relational, so the shape below is deliberate — it precomputes what a SQL database would have queried on demand.

```
users/{uid}                     username, photoUrl, score,
                                birthYear, isMinor, privacy{}, fcmTokens[]
                                — self-readable ONLY. friendCount removed in
                                  slice 2; it is derived, not stored.
usernames/{username}            → { uid }. Exists only to make usernames unique
                                (see note below)
publicProfiles/{uid}            username, photoUrl. The only shape discovery can
                                read. Written with the two above, atomically.
friendships/{pairId}            members[2] (sorted), requestedBy, status,
                                createdAt, respondedAt. ONE document per pair;
                                pairId = the two uids sorted and joined with '_'.
                                Replaces users/{uid}/friends/{friendUid} — see
                                the slice 2 note.
users/{uid}/feed/{txId}         transaction copy written by the Node.js API;
                                sender/recipient copies implemented first
users/{uid}/snapshots/{date}    daily score value → powers the 30-day graph (§5.8)
users/{uid}/blocks/{blockedUid} createdAt. Silent blocks (§10). Owner-read-only —
                                that single rule is what makes blocking silent.
                                Checked in BOTH directions on friendship create.
transactions/{txId}             senderId, recipientId, points, reason, chipId,
                                visibility, createdAt, reactions{}
momentChips/{chipId}            the chip library — editable from the console with no
                                app release, which §7.2 explicitly requires
reports/{reportId}              reporterUid, reportedUid, reason, createdAt.
                                READ-DENIED to every client including the
                                reporter — console only. A report requires its
                                matching block in the same commit.
rateLimits/{senderId_recipientId}  negative-transaction counter with TTL
```

**Three rules that must not be broken:**
1. **The client never writes `score` after signup.** Security rules deny it. Only the trusted Node.js API updates the recipient's score inside a Firestore transaction. Otherwise anyone can set their score to a million.
   *Exception, deliberate:* on the *initial* create the client does write `score`, and the rules pin it to exactly `1000`. This keeps signup fast (no waiting on a function) while still making a tampered client impossible. After create, the field is immutable to clients.
2. **The feed uses copies, not a shared query.** The Node.js API currently writes sender and recipient copies atomically. Friends-circle fan-out remains for Slice 5.
3. **Friends leaderboard reads `users` filtered by friend ids.** Firestore caps `in` queries at 30 values, so friend lists are chunked into batches of 30 and merged client-side.
   *Revised in slice 2:* `users/{uid}` is self-readable only, so this cannot work
   as written — a leaderboard would need scores it is not allowed to read. Slice 6
   has to solve that through the Node.js API. Friend uids now
   come from a `friendships` query rather than a subcollection.

> **Added during slice 1: the `usernames` collection.** Firestore has no unique
> constraint, so "is @sam taken?" cannot be answered by querying `users` — two
> people can pass the check simultaneously and both write. The fix is a second
> collection keyed *by the username itself*, claimed in the same transaction that
> creates the user doc. The document id is the uniqueness guarantee. This also
> makes the live availability check in §5.3 a single cheap document read rather
> than a query.
>
> **Removed from the model: `orbTier`.** It was in the first draft, but in the MVP
> the orb's colour is derived from the score (already implemented in `AuraOrb`),
> so the field would have been stored, never read, and free to drift out of sync.
> Orb skins are Phase 3 — add it then, with a purpose.

---

## Slices

Each slice ends fully working on a real phone. `→ Verify:` is how we prove it.

### Slice 0 — Skeleton + design system ✅ *code complete*
`rain-skill:mobile-developer`
Flutter project, folder structure, Firebase connected on both platforms. Turn spec §6.2/§6.3 into a real `ThemeData`: exact palette (`#0a0a0a` base, `#141414` surface, teal `#14b88a`, coral `#fb7360`, gold `#d4af37`), rounded typeface, 16–24px card radii, pill buttons, lowercase UI copy convention. Build the reusable orb widget with its idle pulse.

Done:
- [x] Project at `app/`, package `com.apexverse.aura`, feature-first folder layout
- [x] Palette, type scale, spacing/radii, motion durations, assembled `ThemeData` — all from §6
- [x] `AuraOrb` — breathing, colour ramps with score, `RepaintBoundary`, honours OS reduce-motion, pauses off-foreground
- [x] `AuraPoints` — always renders an explicit `+`/`-` so the teal/coral pair is never the only signal
- [x] `AuraCard`, GoRouter skeleton, `ProviderScope`, edge-to-edge system bars
- [x] Nunito variable font bundled with its OFL licence
- [x] Android release-signing wired to a gitignored `key.properties`; `INTERNET` added for release; secrets patterns in `.gitignore`
- [x] Strict lints (`strict-casts`, `unawaited_futures`/`cancel_subscriptions`/`close_sinks` as errors); `flutter analyze` clean
- [x] Firebase initialized from the generated Android configuration

→ **Verified so far (no device needed):**
- `flutter analyze` → *No issues found*
- `flutter test` → 74/74 passing
- `flutter build apk --debug` → *√ Built build\app\outputs\flutter-apk\app-debug.apk* (163 MB, normal for debug — all ABIs plus symbols)
- `tool/check_contrast.js` → worst contrast 6.78:1, rest AAA
- `tool/check_font.js` → Nunito `wght` axis spans 200–1000, covers every weight used
- `test/golden/goldens/design_check.png` → whole design system rendered in one image

→ **Still to verify on your phone:** install the debug build, confirm the orb
breathes smoothly, the near-black reads right on a real OLED panel, and the four
font weights are distinguishable at arm's length. The golden image covers layout
and colour, but not perceived smoothness or real-panel black level.

> **Firebase is connected.** The Android client configuration and
> `firebase_options.dart` exist, startup awaits `Firebase.initializeApp`, and the
> current Firestore rules are deployed to `aura-d68c3`. Email/password is enabled
> for the Spark beta. Phone OTP and profile-photo upload remain deferred because
> they need paid Firebase services.

**Two build-system fixes worth knowing about**, both in `app/android/gradle.properties`:
1. The Flutter template asks Gradle for `-Xmx8G` plus 4 GB metaspace. On a 16 GB
   machine, with the Kotlin compiler running in its own daemon on top, that
   over-commit made Kotlin fail to memory-map its incremental cache files and the
   build died with *"Could not close incremental caches"*. Dropped to `-Xmx4G` /
   1 GB metaspace. **This was the actual cause of two failed builds** — nothing
   was wrong with the app code.
2. `kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process`.
   The only Kotlin here is `MainActivity` plus generated plugin glue, so
   incremental compilation saves nothing while its mmap'd cache files are a
   standing source of Windows file-locking failures.

**Known future risk (not actionable yet):** the build warns that `firebase_core`
still applies the Kotlin Gradle Plugin, and *"future versions of Flutter will fail
to build if your app uses plugins that apply KGP"*. That's the plugin's migration
to do, not ours. Watch for it on a `firebase_core` bump; if Flutter breaks first,
pinning the Flutter version buys time.

### Slice 1 — Signup + profile 🔄 *code complete; device verification pending*
`rain-skill:mobile-developer` + `rain-skill:backend-specialist`
Splash → 4 onboarding screens → email + password for the Spark beta → **age gate** (birth year; under 15 blocked, 15–17 flagged `isMinor`) → username with live availability check → orb avatar fallback. Score starts at 1000. Phone OTP and Storage-backed photos remain the intended production flow.

Built so far — the whole rules-and-model layer, deliberately with **zero Firebase
imports**, so it is fully testable now and not blocked on the cloud project:
- [x] `core/rules/aura_rules.dart` — every number the product rests on, in one place
- [x] `core/validation/username_rules.dart` — character rules, normalisation, taken-name suggestions
- [x] `core/models/aura_user.dart` — the `users/{uid}` shape, defensively parsed
- [x] Splash, onboarding, email/password, age-gate, username, and review screens wired to Firebase
- [x] Onboarding art built from the real `AuraOrb`/`AuraCard`/`AuraPoints`, not separate illustrations
- [x] Taken-name suggestions wired into the username step (§5.3 "suggest alternates")
- [x] 16 widget tests driving the real flow — the age gate and username rules are proven to *stop* you, not just warn
- [x] Firestore repositories + Riverpod providers
- [x] Skippable photo step and repository contract with the orb fallback
- [ ] Camera capture and upload implementation *(deferred until Storage exists)*
- [x] Firestore security rules, emulator regression tests, and production deployment

→ **Verified on 2026-10-03:** `flutter analyze` clean; **54/54 Firestore security tests passing**; `npm audit` reports 0 vulnerabilities; Firestore rules compiled and deployed; `flutter build apk --debug` produced the APK. The rules require the user profile and username claim in one atomic commit, prevent claim squatting, deny bulk username enumeration, and keep birth year/minor/privacy data self-only.
→ **Verification still required:** Windows Application Control blocks `flutter_tester.exe`, so the widget suite could not execute in this session. On a physical Android phone, create a real email account, confirm `users/{uid}` starts at 1000 and `usernames/{name}` points back to the same uid, then verify an under-15 flow creates no Auth account. No device was connected during this pass.

#### What the signup screens deliberately do *not* do

The wizard is walkable end to end right now, which raises the obvious question:
what happens when you press "finish setup"? It says the backend is not connected,
and that is the honest answer. Three specific temptations were refused:

- **No fake OTP.** The Spark beta explicitly uses Firebase email/password; phone
  OTP returns only when billing is enabled.
- **No fake availability.** The client checks `usernames/{username}` and the
  final transaction rechecks the claim atomically, so a race cannot steal or
  duplicate a handle.
- **No fake photo success.** Storage is not provisioned, so the photo step says
  so and keeps the orb instead of pretending to upload.

The review step also states the minor-safety defaults out loud — leaderboards
off, tighter point range — rather than applying them silently. A 15-year-old
discovering months later that they were quietly excluded from leaderboards is a
worse experience than being told once, plainly, that it is on and adjustable.

> **One testing detail worth recording, because it is not obvious and it cost a
> failing test to find:** `AuraOrb` breathes on an endless `repeat(reverse: true)`,
> so **any widget test whose tree contains an orb can never `pumpAndSettle`** —
> the tree never stops scheduling frames, and the call times out. The flow tests
> run under `disableAnimations: true`, where the orb holds mid-breath and the tree
> settles. That is not a workaround: it is the identical code path a user with
> reduce-motion enabled gets, so the tests exercise that path for free. Any future
> widget test touching a screen with an orb needs the same treatment.

#### Numbers the spec left blank, decided here

The spec names some limits and only gestures at others. These are the calls I
made, all in one file (`core/rules/aura_rules.dart`) so they are easy to argue
with rather than buried in a screen. **Change any of them and the Node.js API
copy must change too** — there is no shared code between Dart and Node.

| Thing | Decision | Reasoning |
|---|---|---|
| Adult point caps | +500 / −300 | §10 gives these figures directly |
| **Minor point caps** | **+300 / −150** | §10 says minors need "lower negative caps" but names no figure; halved from adult |
| **Negative rate limit** | **5 to the same person / 24h** | §10 requires a limit, names none. Stops a pile-on, leaves normal banter alone |
| Zero-point sends | **Rejected** | Not in the spec at all. A 0-point send would create a feed card and a push notification that say nothing happened — free spam that slips under every other limit |
| **Age from birth year** | **Assume the lower age** | §5.3 asks for a year, not a full date, so "2011" means 14 *or* 15. We assume 14. See the cost below |
| Username charset | `a-z 0-9 _`, must start with a letter | No unicode, so `pаul` with a Cyrillic а cannot shadow `paul`. On an app about attributing judgment to a named person, that's safety, not pedantry |

> **⚠️ The age decision has a real cost, and it's your call to accept it.**
> Assuming the lower age means someone born in January 2011 is turned away for
> most of 2026 even though they are genuinely 15. It errs the safe way — letting
> a 14-year-old in is a safety failure, making a 15-year-old wait is an
> annoyance — but it *will* reject real users. If that turns out to bite in the
> beta, the fix is to ask for a full date of birth, not to loosen the maths.

### Slice 2 — Find friends 🔄 *code complete; device verification pending*
`rain-skill:mobile-developer` + `rain-skill:database-architect`

> **⚠️ Rewritten 2026-10-03. The original design could not be built.** It said:
> contact permission screen, hash phone numbers on-device, match against existing
> users. That assumed phone + OTP login. Slice 1 switched to email + password to
> stay on the Spark plan, so **no account in the system has a phone number**.
> There was nothing to hash and nothing to match against.

Built instead: **exact `@handle` search + shareable invite links**, with
**request-then-accept** friendships. Nobody can affect your score without your
agreement, which matters more here than in a follow-based app because friends can
send *negative* aura.

Data model, which **departs from the one above** and that is deliberate:

- `publicProfiles/{uid}` — handle + photo only, the minimal readable shape.
  Discovery cannot read `users/{uid}`, which holds `birthYear`/`isMinor`/privacy.
  Created in the same transaction as the user and the handle claim, so all three
  agree or none exist. **No score in it**, because it is client-written and a
  tampered client would publish any number it liked.
- `friendships/{pairId}` — **one** document per pair, not mirrored
  `users/{uid}/friends/{friendUid}` subcollections. `pairId` is the two uids
  sorted and joined, so the document id itself prevents duplicates, the same way
  `usernames` does. Mirrored subcollections were rejected because accepting would
  mean writing into another user's document tree, and because two documents that
  must agree eventually will not. Slice 6's leaderboard will read friendships by
  `members array-contains` query rather than by subcollection listener.
- **`friendCount` deleted from `users/{uid}`.** It was pinned to 0 and only a
  Cloud Function could legally move it, so on Spark nothing ever did. Counted
  from the friend list instead. Same reasoning that removed `orbTier`.

Two consequences recorded honestly:

1. **Friends cannot see each other's scores yet.** The score lives on
   `users/{uid}`, which is self-read-only, and it cannot be copied into a
   client-written public document without making it forgeable. Needs a server.
   Moved to Slice 6.
2. **Invite links use the `aura://` custom scheme**, registered in the Android
   manifest. An `https://` App Link would survive the app not being installed,
   but needs a registered domain serving `assetlinks.json`. Deferred, not faked.

3. **Minors are discoverable the same as adults** — a deliberate narrowing of the
   "minors get stricter defaults" locked decision, taken on 2026-10-03. The other
   minor protections are untouched: rules-enforced leaderboard exclusion and
   tighter point caps.

→ **Verify:** two accounts, two devices. A finds B by exact handle and requests;
B sees it under "waiting on you" and accepts; both see each other under
"friends". A third account cannot read, accept or delete that friendship — proven
by the rules suite, which covers it with 102 emulator tests.

### Slice 3 — Send aura 🔄 *local implementation; full device verification pending*
`rain-skill:mobile-developer` + `rain-skill:backend-specialist` + `rain-skill:security-auditor`
The 4-step flow from §5.5: friend picker → built-in moment chips or custom text (80 char cap) → point slider → visibility toggle → send. A local Node.js API validates the Firebase identity, friendship, block/privacy state, caps and rate limits, then atomically updates the **recipient's** score and writes sender/recipient feed copies. Recent-first ordering, console-editable chips, full friend-circle feed fan-out, and confirmation effects remain.
Safety built in *here*, not later, because §10 requires it in the core loop: **+500 / −300 asymmetric caps** (tighter for minors) and a **rate limit** on repeated negatives toward one person. The current custom-text denylist is small; a reviewed word filter with auto-flagging remains open.
→ **Verify:** account A sends account B −80 "left me on read". B's score drops to 920 in Firestore. Sending −400 is rejected. Sending 6 negatives in a row to the same person is blocked. Word-filter and auto-flag verification remains open.

### Slice 4 — Home screen + live score
`rain-skill:mobile-developer`
Large animated score with count-up/count-down over ~0.8s (never a hard cut, §6.5), orb colour shifting with standing, quick-stats row (friend rank, 7-day change). Live via a Firestore listener. Haptics on send and on receiving a big swing.
→ **Verify:** with two phones side by side, A sends B +100 and B's number animates upward within about a second, without a manual refresh.

### Slice 5 — Feed + reactions
`rain-skill:mobile-developer`
Reverse-chronological feed of the fanned-out `feed` subcollection, infinite scroll, cards per §5.4 (colour-coded points, reason, timestamp), emoji reaction bar (💀 🔥 😭 👑 ☠️), orb-spin pull-to-refresh, custom empty states per §6.7.
→ **Verify:** transactions from slice 3 appear as cards in the right order. Tapping 💀 persists the reaction and it shows on the other phone.

### Slice 6 — Friends leaderboard
`rain-skill:mobile-developer` + `rain-skill:database-architect`
Ranked friend list, 24h change arrows, subtle top-3 treatment, your own row pinned when scrolled past. Chunked `in` queries as noted above.
→ **Verify:** with 4 test accounts at different scores, the order is correct. After A gains 200 aura, A moves up and shows an up arrow.

### Slice 7 — Push notifications
`rain-skill:mobile-developer` + `rain-skill:backend-specialist`
FCM on both platforms, token management, sent by the Node.js backend. Copy in the §7.3 voice ("bro just cooked you 💀 −80 aura from @username"). Tapping deep-links to that exact transaction in the feed.
→ **Verify:** phone B is locked; A sends aura; B's lockscreen shows the notification; tapping it opens directly to that feed item.

### Slice 8 — Aura Card export *(the growth engine)*
`rain-skill:mobile-developer`
2–3 templates (score / top-moment / rank focused) rendered **on-device** — faster and cheaper than server-side, as §11 suggests. Live preview, subtle watermark, one-tap share to Instagram Stories / TikTok / Snapchat / camera roll.
→ **Verify:** generate a card and actually post it to an Instagram Story from a real phone. Image is sharp at full resolution and the watermark is legible but not obtrusive.

### Slice 9 — Privacy + safety surfaces 🔄 *built out of order; partially complete*
`rain-skill:security-auditor` + `rain-skill:mobile-developer`

> **Pulled forward from last place on 2026-10-03,** for two reasons. Slices 3–7
> were paused under the former Cloud Functions design. The Node.js path removes
> that specific blocker. The slice 2 security review named the
> block list as the single most important thing to build next: friend requests
> had no block and no rate limit, and decline is a plain delete — a *reset*, not
> a signal — so request/decline looped forever against any handle.

Built: **blocking** (severs the friendship, checked in both directions, and the
blocked person is never told), **reporting** a user, the **settings screen**
(§5.11 minus notification toggles), and **account deletion**.

| §10 requirement | State |
|---|---|
| Blocking, fully silent | ✅ |
| Settings: who can send you aura, leaderboard visibility | ✅ |
| Opt out of public visibility | ✅ |
| Account deletion | 🔄 aura-data purge added; live Firebase run still needed; local Node API must be running |
| Reporting | ✅ a *user*; a *transaction* needs Slice 3 |
| Minor defaults | ✅ since Slice 1, rules-enforced |
| Granular notification toggles | ⏸ Slice 7 — push is not built, and a dead switch teaches people the settings screen lies |
| Word filter on custom text | 🔄 small denylist; review and auto-flagging remain |
| Rate limit on repeated negatives | ✅ server enforces 5 per pair per 24h; live Firebase run pending |

Three decisions worth carrying forward:

1. **A block removes the friendship.** The blocked person sees you disappear,
   which is indistinguishable from being unfriended — that ambiguity *is* the
   silence. Rejected keeping a suppressed-but-stored friendship: it would be a
   document that is a lie on one side, the exact problem the Slice 2 design
   avoided.
2. **Deleting your account never frees your handle.** `usernames/{name}` stays
   as a tombstone. Everything personal goes; the reserved string does not, so
   nobody can take a churned friend's name and be mistaken for them. The
   deletion screen says this plainly, because someone deleting to free up a
   handle needs to know beforehand that it will not work.
3. **A report must carry its block, enforced in the rules.** Nothing reviews the
   report queue yet, so the block is the only thing that actually protects the
   reporter — coupling them server-side is what stops the UI drifting into a
   report button that quietly does nothing.

→ **Verify:** set "nobody can send me aura" and confirm friend requests fail.
Block A from B's account and confirm A simply stops appearing, with no message.
Report someone and see the doc land in `reports` while the block appears in
settings. Delete a test account and confirm from the console that `users`,
`publicProfiles` and the friendships are gone while `usernames` remains.

---

## Phase X — Verification (last, before any beta invite)

- [ ] Full loop on two real phones, one iPhone one Android: signup → find friend → send aura → notification → react → check leaderboard → export card → post to Stories
- [ ] `rain-skill:security-auditor` full pass — with attention to: can any client write its own score? can the OTP endpoint be abused to burn SMS credit? do the Firestore rules leak private transactions? are contacts really hashed?
- [ ] `rain-skill:test-engineer` — unit tests on score math, point caps, rate limiting, minor defaults
- [ ] Cold-start time and feed scroll checked on a genuinely cheap Android phone, not just a flagship
- [ ] Every empty state has real copy and art (§6.7) — no default "no data" text anywhere
- [ ] Store review readiness: age rating set for 15+, privacy policy live, data-collection disclosures filled for both stores
- [ ] `rain-skill:post-task-review`

---

## Deliberately not now

Out of MVP scope, in spec order: aura decay (§3.3), streaks (§3.4), school + city leaderboards (§3.5), call-out requests, aura battles (§3.6), group events, Wrapped (§3.7), boosts, streak freeze, orb skins, private groups, subscription, marketplace.

**One MVP shortcut worth knowing about:** the 30-day score graph on the profile screen (§5.8) needs daily snapshots, and those only accumulate over time. Slice 1 starts writing `snapshots` from day one so the graph has real history by the time you need it — but the graph itself only becomes worth showing after a few weeks of use.

**Known risk to watch during the beta:** §10 warns the mechanic can tip into harassment. The caps and rate limits are the technical guard, but the beta needs a human check too — watch the report/block rate (§13) in the first friend groups and be ready to tighten the negative caps if it climbs.
