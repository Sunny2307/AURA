# Open Questions

## Blocking a slice

- **Account deletion depends on the local API.** The Node purge removes aura
  history across both participants before the client deletes the profile/Auth
  account. For beta, the backend must be hosted reliably so deletion stays
  available whenever a user requests it.

- **How do friends see each other's scores?** `users/{uid}` is self-readable
  only, and a score in the client-written `publicProfiles/{uid}` would be
  forgeable. Blocks the Slice 6 leaderboard and limits the Slice 2 friend list to
  handle + photo. The standalone Node.js API can provide an authenticated score
  read endpoint or write a server-owned score view. See
  [[decisions]].
- **Slice 3 writes sender and recipient feed copies through Node.js.** Slice 5
  still needs controlled friends-circle fan-out and a feed reader UI.

## Verification gaps

- When will an Android device be available to run the real signup and the
  two-account friend-request flow end to end?
- `flutter test` cannot run at all — Windows Application Control blocks
  `flutter_tester.exe` (confirmed again 2026-10-03). Pure-Dart tests now run via
  `dart test test_unit`, which covers models but not widgets. Do widget tests
  move to CI, or does the policy change?
- Firebase CLI needs JDK 17 on **PATH**, not just in `JAVA_HOME` — `java` on this
  machine resolves to Oracle Java 8. Prepend `$JAVA_HOME/bin` before running the
  emulator suite. Should this be baked into the npm script?

## Product

- Should minors stay as discoverable as adults before a public launch? Decided
  yes for the beta on 2026-10-03; flagged for revisit.
- Invite links use the `aura://` custom scheme, which does nothing if the app is
  not installed. An `https://` App Link needs a registered domain. When is a
  domain bought?
- **No rate limit on blocks, reports or friend requests.** The block list
  shipped in slice 9 and closes the harassment loop, but there is still no
  per-user throttle on those direct Firestore writes. The Node.js send endpoint
  has its own limits, but a real account can still write these at volume against a *shared, project-wide*
  daily quota. Cheapest honest mitigation is a Firestore budget alert; recorded
  as residual beta risk.
- **A report can outlive its block.** The `existsAfter` coupling is checked at
  commit only, so an abuser can file a report and then unblock. The rule
  guarantees the UI cannot offer a report without a block, not that a filed
  report stays backed by one. Worth knowing before the queue is ever triaged.
- **Nobody reviews `reports/`.** Before a public beta that needs a person or a
  console workflow, or the button is a promise the product does not keep.
- **The user base is enumerable despite `list: false`.** `usernames/{name}` is
  readable signed-out by design (handle availability is checked before the auth
  account exists), so dictionary-attacking `get` yields a handle-to-uid map, and
  any throwaway account then reads every public profile. The mitigation is **App
  Check** — free on Spark — plus restricting the Android API key to the package
  and release SHA-1. Console work, not code. Do this before any public beta.

## Verification debt, and it is growing

**Slices 1, 2 and 9 all carry unverified end-to-end claims.** Nothing has run on
a physical device since the project started. Each new slice is built on top of
the last, so this is the largest single risk in the project and it compounds.

## Resolved

- ~~Should Slice 2 use username search, invite links, or collect phone numbers
  later?~~ → Username search **and** invite links, decided 2026-10-03.
- ~~When will Firebase billing and Storage be enabled for camera-first profile
  photos?~~ → Still deferred, but now one of several things waiting on Blaze
  rather than a question of its own.
- ~~Should Slice 9 use a block list?~~ → Built 2026-10-03. See
  [[features/safety]].

## The local-server boundary

Firebase stays on Spark. The standalone Node.js API now performs trusted score
updates and sender/recipient feed copies. It runs on the development computer;
its availability therefore depends on that computer being on and reachable.
Before a multi-device closed beta away from that computer, it needs an HTTPS
host. Slices 5–7 still need their own implementation; this architecture removes
the former Cloud Functions/Blaze dependency, not that feature work.

## Sources

- `aura-mvp-plan.md`
- `docs/rain-skill/tasks/2026-10-03-slice-2-find-friends.md`
- `docs/rain-skill/tasks/2026-09-06-firebase-wiring-slice-1-close.md`
