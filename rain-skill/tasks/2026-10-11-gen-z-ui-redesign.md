---
task-id: 2026-10-11-gen-z-ui-redesign
flow: REFACTOR
status: DONE
started: 2026-10-11
completed: 2026-10-11
---

# Task: Redesign Aura's existing UI and UX for a Gen Z audience

## Flow: REFACTOR

Presentation redesign of the existing Flutter app. Preserve repository contracts, stored data, aura rules, privacy, blocking, reporting, and account flows. Visual presentation and navigation affordances may change as explicitly requested by the user.

## Brainstorm
N/A (REFACTOR — no brainstorm). User requests an exceptional, cohesive Gen Z aesthetic and improved usability across the current app.

## Design Direction
- Social collectible: ink-black canvas, electric mint primary accent, warm white typography, deliberate borders and graphic details. Coral retains its negative/error meaning.
- Oversized score and compact bold headings; use the bundled font with deliberate weights and tracking, keeping readable body copy.
- A distinctive score/profile composition, avatar-led people lists, strong selected states, and spacious forms.
- Primary actions close to the thumb zone. Clear labels, visible back navigation, and consistent home/people/send access using existing destinations.
- Restrained press and transition feedback; respect reduced motion and text scaling.
- Demo actions stay available through an explicitly labeled secondary panel; onboarding keeps a clear try-demo entry.
- Chosen over dense neon/glass decoration to keep score, people, and actions legible and preserve the app's recognizable dark identity.

## Plan
- [x] Establish the baseline, read design/defensive-editing references, trace shared callers and preserve source backups.
- [x] Rework shared colors, typography, cards, controls, orb composition and navigation.
- [x] Redesign splash, onboarding, signup/photo steps and home; put demo tools behind a secondary entry.
- [x] Apply the system to friends, search, profile, sending, settings, blocked list and deletion. Shared theme also updates safety sheets.
- [x] Validate 360, 600 and 1200 widths, large text, keyboard visibility, contrast, scroll reachability and reduced motion.
- [x] Security gate — PASSED.
- [x] Code review — APPROVED.
- [x] Verification — completed with the five documented original-baseline failures.
- [x] Update wiki design decisions/architecture and close task record.

## Implementation Notes
### Impact Analysis
- Shared files: `app/lib/core/theme/`, `app/lib/shared/widgets/`; callers span all presentation screens. Audit call sites before changing shared contracts.
- Screens: `features/onboarding/presentation/`, `features/home/presentation/home_screen.dart`, `features/friends/presentation/`, `features/send/presentation/send_aura_screen.dart`, `features/profile/presentation/photo_step.dart`, `features/settings/presentation/`, `features/safety/presentation/safety_menu.dart`.
- Secondary demo UI: `app/lib/prototype/prototype_panel.dart`, `local_photo_step.dart`; preserve store/runtime behavior.
- Routing: inspect `app/lib/core/router/app_router.dart`; retain route guards and invite routes if navigation composition changes.
- Coverage: `app/test/design_system_test.dart`, `app/test/features/{onboarding,friends,send_aura,safety,prototype}_flow_test.dart`, golden design check, and `app/test_unit/`.
- Public repository/API contracts: no changes planned.
- Database/backend/security-rule changes: no changes planned.
- Current startup defaults to persistent local prototype. Existing wiki records a historical Windows restriction on widget tests; recheck current availability during baseline.

## Security Gate
PASSED — preservation review of auth guards, private/public profile boundaries,
minor defaults, send caps/idempotency, blocking/reporting and deletion. Hash
comparison confirms only presentation, theme, shared visual widgets and the
photo-route back affordance changed in lib. Models, repositories, application
services, persistent store, backend and security rules were not changed. Demo
labeling remains explicit; home failures no longer expose raw exception text.

## Code Review
APPROVED — complete source diff and shared callers reviewed. No added packages
or placeholder product actions. Top-level navigation avoids stacked duplicate
screens; deep screen back buttons return home when opened directly. Review found
and corrected zero-duration carousel animation under reduced motion, large-text
onboarding artwork sizing, signup review wrapping, and keyboard-safe send footer.
Existing settings tests now scroll to the visibility switch; demo-panel assertions
scroll to the intentionally secondary panel. Existing golden updated deliberately.

Caller trace: `docs/rain-skill/tasks/gen-z-caller-trace.txt`.
Review diff: `docs/rain-skill/tasks/evidence/2026-10-11-gen-z-ui/source.diff`.
Rollback: restore only the changed files from
`docs/rain-skill/backups/2026-10-11-gen-z-ui/lib` and `/test`, remove the new
`aura_identity.dart` and `redesign_layout_test.dart`, and restore the saved golden.
Do not reset the untracked project or unrelated work.

## Verification
Observed on Flutter 3.47.2 / Dart 3.13.2 using approved native runtime access:

- Original-source baseline: 122 passed, 5 failed (`baseline-original.log`).
- Final Flutter suite: 131 passed, the same 5 failed (`final-flutter-tests.log`).
  Failures are self-handle search, two signup credential error fixtures, blocking
  friend-list removal, and deletion's router-less test host. No new failures.
- Eight redesign tests pass: six width/text combinations, complete local
  demo/navigation/search/send workflow, and narrow-phone signup at 200% text
  with keyboard. Send workflow confirms actual score mutation and navigation.
- Pure Dart: 43 passed (`dart-unit.log`).
- Focused redesign, demo, sending and design-system suite: 24 passed
  (`focused-final.log`).
- Flutter analysis: no issues (`analysis.log`).
- Android debug APK built successfully (`android-build.log`):
  `app/build/app/outputs/flutter-apk/app-debug.apk`.
- Real rendered previews inspected: home, onboarding, friends, settings, send,
  send detail, discovery and profile. PNGs are in the evidence directory.
- Theme tests check 4.5:1 text and 3:1 control-border contrast. Full OS text
  scaling and reduced motion remain supported.
- No Android device connected; physical-device installation/smoke is unverified.

All evidence is under `docs/rain-skill/tasks/evidence/2026-10-11-gen-z-ui/`.
Wiki updated: INDEX, architecture, decisions, new design-system page.

## Final Status: DONE

User approved the plan with “yes”. The requested redesign is implemented and
reviewed, with an installable Android build and documented verification limits.
