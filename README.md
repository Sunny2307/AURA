# Aura app prototype

The app runs in local prototype mode by default. No Firebase setup or backend
server is needed. Run `flutter run` from this folder, or install the debug APK.

- Tap **try the demo** to open a prepared account, or complete signup with dummy
  details. Prototype passwords are not stored or verified.
- Sam and Maya are accepted friends. Alex has sent you a request. Search
  `jordan` to try sending a new request.
- Use **view as / return to demo account** to act as another person. Accept a
  request as its recipient, or switch to someone who received aura to see their
  updated score. Your own score does not change when you send.
- The home prototype card shows recent local aura activity. Friends, requests,
  scores, settings, reports, selected photos and session state survive app restarts.
- Profile photos are selected from the device and copied into private app storage.
  They are not uploaded. Skipping keeps the orb.
- **reset prototype** clears saved demo progress after confirmation and lets you
  repeat onboarding and deletion flows. Deleting an account reserves its handle
  until a prototype reset, matching the existing app behavior.

Use dummy details: local demo accounts can be switched without passwords, and
saved demo data is not encrypted. Reports are simulated locally, not delivered
to a moderation service. Uninstalling the app removes the local prototype.

The separate server lives in `../backend/`. For future integration work only,
`flutter run --dart-define=AURA_PROTOTYPE=false` selects the original Firebase
repositories and HTTP API. Keep that mode separate from prototype testing.

Verification commands: `flutter analyze`, `dart test test_unit`, and
`flutter test test/features/prototype_flow_test.dart`. Full-suite pre-existing
failures and observed results are recorded in
`../docs/rain-skill/tasks/2026-10-11-local-app-prototype.md`.
