# Decisions

## 2026-10-11 — A collectible identity with readable social flows

Use warm ink, electric mint, bundled Nunito typography and an orbit-framed live
score as Aura's visual signature. Prioritize labeled navigation, thumb-reachable
actions, readable selection states and scrollable forms. Preserve full OS text
scaling and reduced motion. Dense neon/glass decoration was rejected because it
competes with scores, people and actions. Public profiles display only supported
public data; the redesign does not invent scores or leaderboard activity.

Source: `docs/rain-skill/tasks/2026-10-11-gen-z-ui-redesign.md`,
`app/lib/core/theme/`, `app/lib/shared/widgets/aura_identity.dart`, [[design-system]].

## 2026-10-11 — Focus on the app with persistent local prototype data

The user chose saved local demo data while postponing backend integration.
Normal startup overrides repository interfaces with a shared local store and
skips Firebase. Real integrations remain opt-in. Local mutations save before
notifying observers, rollback on storage errors, and preserve cross-screen state.
Use view-as controls to test both participants on one device.

Source: [local-app-prototype](../../tasks/2026-10-11-local-app-prototype.md),
`app/lib/prototype/`, [[features/local-app-prototype]].

## 2026-10-11 — Keep the backend beside the Flutter app

The standalone Node.js server lives in `backend/` at the Aura project root,
alongside the Flutter application in `app/`. Moving the complete folder preserves
its internal imports, dependencies and tests. The mobile app continues to use
the same HTTP API URL. `backend/.gitignore` preserves exclusions for dependencies,
cache and credentials outside the app folder.

Git metadata remains at `app/.git`; the sibling backend is outside that repository.
Repository consolidation remains a separate decision.

Source: [separate-backend-folder](../../tasks/2026-10-11-separate-backend-folder.md),
`backend/package.json`, `backend/.gitignore`, `backend/src/server.js`.

## 2026-10-04 — Keep Spark and use a standalone Node.js API

Firebase Auth and Firestore remain on Spark. A Node.js process on the developer
computer verifies Firebase ID tokens and commits recipient score changes and
transaction records with the Admin SDK. The rejected Firestore-watching worker
would have required more request-state and replay handling. This local process
is a development backend; beta use needs HTTPS hosting.


## 2026-10-03 — A block removes the friendship

The blocked person sees you disappear, which is indistinguishable from being
unfriended — that ambiguity *is* the silence. Rejected keeping a
suppressed-but-stored friendship: it would be a document that is a lie on one
side, the exact problem the slice 2 single-document design avoided.

Checked in both directions, so blocking someone also stops you re-requesting
them. Blocking half a relationship is not blocking.

## 2026-10-03 — Deleting your account never frees your handle

`usernames/{name}` survives as a tombstone holding a uid that no longer
resolves. Everything personal goes; the reserved string does not.

Freeing it would let someone squat a churned friend's name the moment they left,
and every old mention of `@sam` would silently start pointing at a different
person. The deletion screen says this plainly — someone deleting in order to
free up a handle for a second account needs to know beforehand that it will not
work.

Rejected deferring deletion to Blaze: it would ship a beta to minors with no way
to leave.

## 2026-10-03 — A report must carry its block

Enforced in the rules with `existsAfter`, not just in the UI. Nothing reviews the
report queue yet, so the block is the only thing that actually protects the
reporter today; a report that did nothing visible would be worse than no report
button, because it implies a protection that does not exist.

Reasons are a closed enum rather than free text: free text about a named person
would itself be the unmoderated channel the report form exists to address.

## 2026-10-03 — No notification toggles in settings

Push is Slice 7 and Blaze-blocked. Real switches writing fields nothing reads
would teach people that the settings screen lies, which costs more than the
missing row.

## 2026-10-03 — A friendship is one document, not two

`friendships/{pairId}`, with `pairId` derived from the two uids sorted, replaces
the mirrored `users/{uid}/friends/{friendUid}` subcollections the MVP plan
specifies.

Rejected the mirrored design because accepting a request would mean writing into
another user's document tree — the widest security surface the app would have —
and because two documents that must agree will eventually disagree with nothing
in the system noticing. One document cannot half-exist.

**Cost:** Slice 6's leaderboard reads friendships by `members array-contains`
query rather than by subcollection listener, and needs a composite index.

## 2026-10-03 — Discovery is exact handle plus invite link

Phone-number contact matching, which the plan specifies for slice 2, cannot be
built: slice 1 moved to email + password, so no account has a phone number to
hash. Rejected collecting phone numbers now — it reintroduces PII for a
minor-heavy audience and still needs Blaze for OTP, so the numbers would be
unverified and spoofable.

`list` stays denied on `usernames` and `publicProfiles`, so there is no
enumeration path even if a later screen wanted one.

## 2026-10-03 — Friendships require consent

Request-then-accept, not one-sided follow. Only the member who is not
`requestedBy` may flip `pending` to `accepted`. This matters more here than in a
follow-based app because friends can send *negative* aura — a one-sided add would
let a stranger start lowering your score without your agreement.

## 2026-10-03 — Minors are discoverable the same as adults

A deliberate narrowing of the "minors get stricter defaults" locked decision,
chosen by the user on 2026-10-03 so friend groups can form normally in a 15–22
app.

Everything else protecting minors is untouched: rules-enforced leaderboard
exclusion, tighter point caps, and `isMinor` defaulting to true when data is
missing. Worth revisiting before any public launch.

## 2026-10-03 — `friendCount` is derived, not stored

Removed from `users/{uid}` entirely rather than left at zero. Only a Cloud
Function could legally move it and the Spark plan has none, so the stored value
could only ever be wrong. Also rejected opening a rules-guarded cross-user `+/-1`
write — the first write path into someone else's document, for a number that can
simply be counted.

## 2026-10-03 — No score in the public profile

`publicProfiles/{uid}` carries only handle and photo. It is client-written, so a
score in it would be forgeable and would show as real in every search result and
friend list. The consequence is accepted and visible: **friends cannot see each
other's scores until there is a server.** See [[open-questions]].

## 2026-10-03 — Keep private profile data self-only

`users/{uid}` remains self-readable because it contains birth year, minor state, and privacy settings. Slice 2 will add a separate minimal public-profile document for discovery rather than exposing the full account document.

## 2026-09-06 — Use email/password for the Spark beta

Phone OTP, Cloud Functions, and profile-photo Storage remain deferred until Firebase billing is enabled. Email/password keeps Slice 1 usable on Spark, with a documented cost to contact-based discovery in Slice 2.

## Sources

- Task: `docs/rain-skill/tasks/2026-09-06-firebase-wiring-slice-1-close.md`
