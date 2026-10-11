# Firebase Signup

Slice 1 uses Firebase email/password on the Spark plan. The flow collects credentials, runs the age gate, checks username availability, shows the review, then creates the Auth account immediately before the atomic Firestore profile and username transaction. An under-age rejection therefore creates no authenticated account.

Phone OTP and Storage-backed profile photos remain deferred. The current photo step is explicit about Storage being unavailable and keeps the score-driven orb as the avatar.

Security rules were hardened and deployed on 2026-10-03. The emulator suite passed 54 tests, dependency audit found zero vulnerabilities, Flutter analysis passed, and a debug APK built. Widget tests are blocked on this machine by Windows Application Control, and the real signup still needs a connected Android device.

## Sources

- Task: `docs/rain-skill/tasks/2026-09-06-firebase-wiring-slice-1-close.md`
- Code: `app/lib/features/onboarding/presentation/signup_flow_screen.dart`, `app/lib/features/auth/data/user_repository.dart`, `app/firestore.rules`
