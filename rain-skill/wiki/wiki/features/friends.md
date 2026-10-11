# Friends — Slice 2

Finding people, requesting, accepting, and the friend list. Built 2026-10-03.

See [[data-model]] for the collections and [[decisions]] for why the design
departs from `aura-mvp-plan.md`.

## How someone is found

Two ways in, both landing on the same control:

1. **Exact `@handle` search** — `add a friend` screen. The handle is shape-checked
   offline by `UsernameRules.check` before any read, so a malformed handle never
   reaches Firestore. Then two document reads: `usernames/{name}` → uid, then
   `publicProfiles/{uid}` → the profile. Two reads rather than one query, because
   a query would need `list` access to `publicProfiles` — the enumeration hole
   the rules close.
2. **Invite link** — `aura://u/<handle>`, copied to the clipboard from the
   friends screen, pasted into whatever group chat the friend group already uses.
   Registered as an Android `intent-filter` with
   `flutter_deeplinking_enabled`.

There is no partial match, no suggestions, no directory.

## The states two people can be in

`FriendActionButton` is one widget watching one live document, rather than an Add
button on one screen and an Accept button on another. If someone accepts while
you are looking at their profile, the button becomes "friends" without a refresh.

| Friendship document | Button |
|---|---|
| none | **add** |
| pending, you sent it | **requested** → tap to cancel, confirmed |
| pending, they sent it | **accept** / **decline** |
| accepted | **friends** → tap to unfriend, confirmed |

The sender can never accept their own request. That is enforced in the security
rules (`request.auth.uid != resource.data.requestedBy`), mirrored in
`Friendship.isIncomingFor`, and covered by a rules test and a model test.

## Key files

| Path | What |
|---|---|
| `app/lib/core/models/friendship.dart` | Model + `pairIdFor` |
| `app/lib/core/models/public_profile.dart` | The discovery shape |
| `app/lib/features/friends/data/friendship_repository.dart` | Reads/writes, transactional |
| `app/lib/features/friends/data/public_profile_repository.dart` | Handle → profile |
| `app/lib/features/friends/application/friends_providers.dart` | Live lists, derived friend count |
| `app/lib/features/friends/application/friend_search_controller.dart` | Search states |
| `app/lib/features/friends/presentation/` | Three screens + two widgets |
| `app/firestore.rules` | `publicProfiles` and `friendships` blocks |

## Gotchas worth remembering

- **`pairId` ordering must match between client and rules.** The client sorts
  with Dart's UTF-16 `compareTo`; the rules use Firestore's UTF-8 `<`. These agree
  across ASCII, and Firebase Auth uids are `[A-Za-z0-9]{28}`, so it holds — but a
  uid source outside that set would silently break every write with a bare
  `permission-denied`. Covered by a test.
- **Cold start from an invite link races auth.** `publicProfiles` denies
  signed-out reads, so a lookup fired before the auth stream emits fails.
  `profileByUsernameProvider` awaits `authStateProvider.future` first, and the
  route guard stays put while auth is `SignupStatus.resolving` rather than
  bouncing to splash and losing the link. It does **not** stay put on
  `SignupStatus.failed` — those were one `unknown` case until the security
  review pointed out that a revoked token then read as "give it a moment" and
  walked straight through the guard.
- **The friend list shows no scores.** Not an oversight — see [[decisions]].

## Two mistakes the security review caught

Both looked correct in review and were only falsified by running something.

1. **`photoUrl` accepted any string**, and this screen renders a *pending*
   request's photo before any accept — so an arbitrary URL was a
   zero-interaction IP/location/timing beacon, fired by sending an unsolicited
   request to a handle, at an audience that includes 15-year-olds. The rules now
   require `null` until Cloud Storage exists, with the bucket-prefix replacement
   written down in `isAllowedPhotoUrl`.
2. **`aura://u/<handle>` is not the path `/u/<handle>`.** The `u` is the URI
   *authority*; the path is `/<handle>`, and go_router matches on path alone. The
   invite link would have dead-ended on every share, and `aura://x/_design`
   reached the developer screen in release builds. The link is now
   `aura:///u/<handle>` with an empty authority, `/_design` is compiled out under
   `kDebugMode`, and `test_unit/invite_link_test.dart` asserts the two-slash form
   does *not* work so nobody simplifies it back.

Also closed: a signed-in principal with no account could send requests that
counted on the recipient's screen but rendered as nothing — invisible,
undeclinable spam from a token that never passed the age gate.

## Verification status

- ✅ 102 emulator rules tests (`npm test` in `app/firestore-tests/`)
- ✅ 22 pure-Dart tests (`dart test test_unit`)
- ⛔ Widget tests written at `app/test/features/friends_flow_test.dart` but
  **never executed** — `flutter_tester.exe` is blocked. See [[open-questions]].
- ⛔ Two-account device run still pending.

## Sources

- Task: `docs/rain-skill/tasks/2026-10-03-slice-2-find-friends.md`
- Related: [[features/firebase-signup]], [[data-model]], [[architecture]]
