# Design System

Aura uses a social collectible direction: warm ink `#0C100F`, mint `#B5F5CE`,
warm white `#F6F5EF`, and quiet solid surfaces. Coral retains its negative/error
meaning. Use the bundled Nunito font, bold editorial headings, a prominent live
score, and restrained orbit details. Reuse theme tokens and shared components
instead of introducing per-screen palettes.

## Interaction rules

- Home, people and settings have labeled navigation. Sending is a persistent
  home action; deeper screens expose back navigation with a home fallback.
- Forms scroll, selected controls have clear borders, and submission remains
  reachable with the keyboard open.
- Preserve OS text scaling and reduced motion. Wrap people controls at large
  text sizes; cap wider content at 640 logical pixels.
- Keep local demo status visible. Demo tools live behind a secondary panel.
- Render real repository data. Public profile previews cannot invent scores.
  Auth, privacy, minor restrictions and send rules remain authoritative.

## Evidence

`app/test/features/redesign_layout_test.dart` covers 360, 600 and 1200 logical
pixel widths, up to 200% text, keyboard reachability, signup, demo controls,
navigation, discovery and a real local send. `app/test/design_system_test.dart`
checks text contrast of at least 4.5:1 and control outlines of at least 3:1.
Rendered screen captures are saved under
`docs/rain-skill/tasks/evidence/2026-10-11-gen-z-ui/`.

Sources: `app/lib/core/theme/`, `app/lib/shared/widgets/aura_identity.dart`,
`app/lib/app.dart`, `docs/rain-skill/tasks/2026-10-11-gen-z-ui-redesign.md`.
