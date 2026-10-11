# Local app prototype

The current app defaults to `AURA_PROTOTYPE=true`: no Firebase initialization or
backend calls. A shared device-only store implements the existing repository
interfaces and saves versioned JSON through SharedPreferencesAsync. Sessions,
profiles, friendships, privacy, blocks, reports and aura sends survive restart.
Passwords and Firebase tokens are not stored.

Try the demo creates an adult account, two accepted friends and an incoming
request. Sample accounts can be selected with view-as controls to accept outgoing
requests, observe recipient scores and repeat interactions on one device. Reset
requires confirmation and clears the prototype. Local account deletion retains
username claims until reset, removes personal records and never re-creates the
deleted account during reload.

Photo selection uses image_picker and copies the image into app-private documents.
Prototype photo rendering accepts only file URLs. Replacement, account deletion
and reset clean up referenced photos with paths constrained to the app's photo
folder. Cleanup is best effort if the filesystem fails.

The local demo has passwordless account switching and unencrypted demo data;
use dummy details. Reports are local simulations, not moderation submissions.
The report sheet scrolls so all options are reachable on smaller screens.

Integration code remains available only with `--dart-define=AURA_PROTOTYPE=false`.
The sibling `backend/` is unchanged. This does not implement future feed,
leaderboard or push-notification slices.

## Sources
- `app/lib/main.dart`, `app/lib/prototype/`, `app/lib/shared/widgets/profile_photo.dart`
- `app/test_unit/prototype_store_test.dart`, `app/test/features/prototype_flow_test.dart`
- [Task](../../../tasks/2026-10-11-local-app-prototype.md)
