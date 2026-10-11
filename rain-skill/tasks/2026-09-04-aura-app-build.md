# Task: Aura App — Build Plan from Product Spec

- **Date:** 2026-09-04
- **Flow:** NEW_PROJECT
- **Source spec:** `aura_app_full_product_plan.md` (project root, 389 lines, complete product plan)
- **Requested via:** `/rain-skill:plan`
- **Status:** ⏸ Awaiting brainstorm answers

---

## Request

Read the markdown file in the project root and create a proper implementation plan for it.

## Definition of Done

A written implementation plan file in the project root that decomposes the Aura product
spec into buildable phases and tasks, with agent assignments, dependency order, and a
verification checklist. **No code written in this task.**

---

## Context Check (Phase -1)

| Check | Result |
|---|---|
| Existing codebase | ❌ None — project root contains only the spec `.md` |
| Git repository | ❌ Not initialized |
| Package manifest | ❌ None |
| Prior wiki context | ❌ None — `docs/rain-skill/wiki/` did not exist, initialized this task |
| Prior task records | ❌ None — this is the first |

**Conclusion:** True greenfield. Every stack decision is open. Product/UX decisions are
already made in detail by the spec and should be treated as given, not re-litigated.

---

## What the spec already decides (do NOT re-ask)

- **Product concept & mechanics** — aura transactions (-500..+500), score baseline 1000,
  decay, streaks, leaderboards, battles, Wrapped (spec §3)
- **Feature scope by phase** — MVP features 1–11, Phase 2 features 12–18, Phase 3
  features 19–25 (spec §4)
- **Full screen-by-screen UX** — 11 screens specified (spec §5)
- **Design system** — dark-first, exact hex palette, rounded sans typography, motion and
  haptics rules, 16–24px radii, pill buttons (spec §6)
- **Copy voice & starter content** — lowercase UI copy, moment-chip library, notification
  copy samples (spec §7)
- **Growth, monetization, and metrics strategy** (spec §8, §9, §13)
- **Safety requirements** — asymmetric point caps, rate limiting, reporting, silent
  blocking, word filtering, minor defaults, full privacy opt-out (spec §10)
- **Roadmap shape** — Phase 0 through Phase 4 with week/month targets (spec §12)

## What the spec leaves genuinely open (the brainstorm)

- Mobile framework: "React Native **or** Flutter" — undecided (spec §11)
- Backend: "Node.js **or similar**" + real-time layer "WebSockets **or** a managed
  real-time database" — undecided (spec §11)
- Phone/OTP provider and its per-SMS cost — unspecified
- Whether under-18 users are supported at all ("**if** users under 18 are
  supported…", spec §10) — this gates App Store compliance and safety defaults
- Team size / who is building — the week-numbered roadmap assumes a resourcing level
  that is never stated
- Existing assets: Figma designs, brand files, Apple/Google developer accounts
- Launch platform order: iOS first, Android first, or both simultaneously

---

## Brainstorm

✅ **Complete 2026-09-04.** Asked as multiple-choice at the user's request (they asked for
options + a recommendation rather than open-ended questions — noted as a standing
preference).

| # | Question | Answer | Matched my rec? |
|---|---|---|---|
| 1 | Plan scope | MVP only (features 1–11) | ✅ yes |
| 2 | Mobile framework | **Flutter** | ❌ I suggested React Native |
| 3 | Backend | **Firebase** | ❌ I suggested Supabase |
| 4 | Under-18 users | Allowed, 15+, stricter defaults | ✅ yes |
| 5 | Who builds | User + Claude | — |
| 6 | Existing assets | Google Play account only | — |
| 7 | Launch platform | Both phones together | ✅ yes |
| 8 | Build order | Vertical slices, one feature fully working at a time | ✅ yes |

**Confirmed approach:** Flutter + Firebase (Auth, Firestore, Cloud Functions, FCM,
Storage), built as vertical slices so each feature works end-to-end on a real device
before the next begins. Flutter + Firebase is a well-matched pair — both Google, and
FlutterFire is mature — so the two answers that diverged from my recommendation are
coherent together.

**Trade-off accepted:** Firestore is not relational, so the leaderboard, the 30-day score
graph (§5.8), and later the decay job cannot be live SQL-style queries. The plan absorbs
this with a fan-out feed, daily score snapshots, denormalized score fields, and chunked
`in` queries (Firestore caps those at 30 values). This was flagged to the user before the
plan was written.

**Blockers surfaced to the user:**
- No Apple Developer account, but they chose to launch on both phones → $99/yr purchase
  is a hard prerequisite for *any* iPhone testing. In the plan's pre-slice section.
- Firebase Blaze plan required for Cloud Functions + phone-auth SMS → real per-message
  cost, so the OTP endpoint needs abuse protection from day one.
- No Figma designs and no brand/logo files → Phase 0 must produce them. Mitigated by spec
  §6 being detailed enough to translate directly into Flutter `ThemeData`.

## Plan

✅ **Written: [`aura-mvp-plan.md`](../../../aura-mvp-plan.md)** (project root).

10 vertical slices (0–9) plus Phase X verification, each with a concrete `→ Verify:` step
performed on real hardware. Includes the Firestore data model with three
must-not-break rules, agent assignments per slice, and an explicit out-of-scope list.

**Deviation from spec noted in the plan:** spec §10 demands safety be in the core loop
"from day one," so the structural safety rules (asymmetric +500/−300 caps, negative-send
rate limiting, word filtering) are built into Slice 3 alongside the send flow rather than
deferred to the safety slice. Slice 9 carries only the user-facing surfaces (settings,
report, block).

⏸ **Awaiting plan confirmation from the user before any code is written.**

## Security Gate

⏸ Pending — runs in Phase X. This app handles minors' PII, phone numbers, contact-book
uploads, and user-generated text about named third parties. Specific things to attack:
client-side score writes, OTP abuse burning SMS credit, Firestore rules leaking private
transactions, and whether contacts are genuinely hashed on-device.

## Post-Task Review

⏸ Pending.
