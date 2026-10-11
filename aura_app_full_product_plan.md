# AURA — Full Product Plan
### A social currency app for Gen Z, built by ApexVerse

---

## 1. Executive Summary

**Aura** is a social app where friends assign each other "aura points" for real-life moments — good or bad. It turns everyday social judgment (the thing Gen Z already does constantly in group chats) into a gamified, competitive, screenshot-native experience.

The entire product is built around three forces that drive virality among Gen Z:
1. **Identity performance** — a score becomes part of how you present yourself online
2. **Social proof / competition** — leaderboards and rankings among people you actually know
3. **Native shareability** — every core interaction produces content designed to leave the app (Stories, TikTok, Snap)

Tagline: **"Your reputation, gamified."**

---

## 2. Vision & Positioning

### 2.1 What Aura Is
- A lightweight, daily-use social app layered on top of existing friend groups
- Not a dating app, not a messaging replacement — it's a companion layer that makes hanging out and group chat dynamics more fun and competitive
- The "currency" (aura points) has no real-world value — it is purely social/status currency, which is what makes it fun and low-stakes enough to go viral

### 2.2 What Aura Is Not
- Not a bullying tool — heavy safety rails are required (see Section 10)
- Not a public stranger-rating app — it works best within real friend circles, not anonymous strangers rating each other
- Not trying to replace Instagram/Snap — it's a companion app, and sharing OUT to those platforms is core to the growth strategy

### 2.3 Target Audience
- Primary: Ages 15–22, high school and early college students
- Secondary: Ages 22–27, young professionals who still want the "friend group game" dynamic
- Persona anchor: "Maya," 17, has 4 different close friend groups, posts to close friends story daily, lives partly through group chat inside jokes, screenshots everything funny to repost

---

## 3. Core Concept & Mechanics (Deep Detail)

### 3.1 The Aura Transaction
This is the atomic unit of the entire app. Every transaction has:
- **Sender** (who gave/took the aura)
- **Recipient** (who received it)
- **Point value** (-500 to +500, default range; can expand with premium)
- **Reason** — either a preset "moment chip" (see 8.2) or free text (max 80 characters, meme-length)
- **Timestamp**
- **Visibility** — private (only sender/recipient see it), friends (shows in feed), or public (shows on public leaderboard activity, opt-in only)
- **Reactions** — emoji reactions from mutual friends who can see it (💀 🔥 😭 👑 ☠️)

### 3.2 The Aura Score
- Each user has one running total score, starting at a neutral baseline (suggest starting everyone at **1000** — feels like a "credit score" reference point, familiar and psychologically meaningful)
- Score updates in real time with an animated count-up/count-down whenever a transaction posts
- Score is visible on your profile, and optionally on public leaderboards if the user opts in

### 3.3 Aura Decay (Retention Mechanic)
- If a user sends or receives zero transactions in 48 hours, their score begins to slowly decay (e.g., -1% per day of inactivity, capped so it can't go below a floor)
- This creates the same psychological pull as Snapchat streaks — "I need to open this app or I start losing points passively"
- Decay should NEVER be so aggressive that it feels punishing — it's a nudge, not a punishment

### 3.4 Streaks
- Two friends who exchange aura (in either direction) on consecutive days build a streak counter, shown as a small flame/spark icon next to their name in your friend list
- Streak breaks if 24 hours pass with zero exchange
- Streak freezes can be purchased or earned (see Section 9)

### 3.5 Leaderboards
- **Friends leaderboard**: default view, ranks your mutual friend circle
- **School leaderboard**: opt-in, requires school verification (via .edu email or manual entry + community flagging for accuracy)
- **City leaderboard**: opt-in, broader and more aspirational/aggressive competition
- Leaderboards refresh live and show rank movement (up/down arrows) to create constant re-engagement

### 3.6 Aura Battles (Phase 2)
- Two users can challenge each other to a 7-day "battle" — whoever gains the most net aura in that window wins
- Result is auto-generated as a shareable card at the end ("I beat @username in an Aura Battle 🏆")
- This is a pure virality mechanic — it manufactures a reason for two people to publicly and repeatedly interact with the app

### 3.7 Aura Wrapped (Phase 2/3)
- Monthly and yearly auto-generated recap, styled after Spotify Wrapped
- Includes: total aura gained/lost, biggest single gain, biggest single loss, most active friend, funniest/most reacted transaction, rank changes over time
- This is designed purely to be shared externally — the entire screen sequence should be swipeable and screenshot/export-friendly, like a Stories-format recap

---

## 4. Full Feature List

### 4.1 MVP (Launch — Must Have)

| # | Feature | Detail |
|---|---|---|
| 1 | Sign-up / Auth | Phone number + OTP (fastest, most Gen-Z-familiar flow), optional Instagram/Snap account link for profile picture import |
| 2 | Contact sync | Immediately after signup, prompt to sync contacts to find friends already on Aura |
| 3 | Profile creation | Username, profile photo, optional bio, orb color unlocks as score grows |
| 4 | Send Aura | Core flow: pick friend → pick moment chip or write custom → pick point value → send |
| 5 | Aura Score | Real-time animated score on home screen |
| 6 | Aura Feed | Scrollable, chronological feed of all transactions involving your friend circle |
| 7 | Reactions | Emoji reactions on feed items |
| 8 | Friends Leaderboard | Ranked list, live updating |
| 9 | Aura Card export | One-tap shareable image generator for Stories/TikTok/Snap |
| 10 | Push notifications | Real-time alerts when you gain/lose aura |
| 11 | Privacy controls | Who can send you aura (everyone / friends only / nobody), leaderboard visibility toggle |

### 4.2 Phase 2 (Growth Features, first 3 months post-launch)

| # | Feature | Detail |
|---|---|---|
| 12 | Aura Decay | Passive score decay on inactivity |
| 13 | Streaks | Daily exchange streak tracking with flame icon |
| 14 | School Leaderboard | Opt-in, school-verified leaderboard |
| 15 | City Leaderboard | Opt-in, broader public leaderboard |
| 16 | Call-Out Requests | Publicly ask a friend to explain a transaction — generates comedic/dramatic content |
| 17 | Aura Battles | Head-to-head 7-day competitions between two users |
| 18 | Group Aura Events | Group-wide point pools for events (e.g., a party, a trip) where the whole group can react |

### 4.3 Phase 3 (Retention + Monetization Layer, months 3–6)

| # | Feature | Detail |
|---|---|---|
| 19 | Aura Wrapped | Monthly/yearly recap cards |
| 20 | Aura Boosts | Temporary point multiplier (rewarded ad or IAP) |
| 21 | Streak Freeze | Protects a streak for one missed day (IAP or earned via engagement) |
| 22 | Custom Orb Skins | Cosmetic profile orb themes (holographic, chrome, neon, seasonal drops) |
| 23 | Private Groups | Smaller closed leaderboards for tight friend circles, paid tier |
| 24 | Ad-free / Verified Tier | Subscription removing ads, unlocking unlimited custom point ranges, exclusive skins |
| 25 | Aura Marketplace (future) | Limited-drop cosmetic items, seasonal event skins — creates FOMO-driven spend |

---

## 5. Full Screen-by-Screen UX Specification

### 5.1 Splash Screen
- Duration: max 1.5–2 seconds
- Visual: teal orb pulsing once, brand wordmark fades in beneath
- Purpose: fast load perception, brand imprint

### 5.2 Onboarding (3–4 swipeable screens)
- Screen 1: "Your friends already judge you. Now it's official." — orb visual with a wobbling score number
- Screen 2: "Send aura for the wins. Take it for the fails." — example transaction card animation
- Screen 3: "Flex your score. Or hide it. Your call." — leaderboard + privacy toggle preview
- Screen 4: Contact permission + notification permission requests, framed casually ("we'll tell you the second someone takes your aura")

### 5.3 Sign-Up Flow
- Phone number entry → OTP code → username selection (real-time availability check, suggest alternates if taken) → profile photo upload (camera-first, not gallery-first, to encourage authentic photos) → contact sync prompt

### 5.4 Home Screen
- **Top**: Large animated Aura Score number, orb visual behind/around it that glows/shifts color based on current standing (bright teal at high score, dimmer/grayish at low score)
- **Below score**: Quick stats row — rank among friends, 7-day change (+/- with arrow), current streak count
- **Main body**: Aura Feed, reverse chronological, each item is a card showing: sender → recipient, point value (color-coded teal for positive, coral for negative), reason text, reaction bar, timestamp
- **Floating action button**: Bottom center, "+" to send aura, always accessible

### 5.5 Send Aura Screen
- Step 1: Friend picker (searchable list, most-recent-interacted friends shown first)
- Step 2: Moment chip selector — horizontally scrollable chips of preset phrases (see Section 8.2), or "write your own" text field
- Step 3: Point slider — visual slider from -500 to +500, color shifts from coral (negative) through neutral gray (zero) to teal (positive) as you drag
- Step 4: Visibility toggle (private / friends / public) and Send button
- Confirmation: brief full-screen animation (particle burst for positive, subtle screen-crack/dim effect for negative) before returning to feed

### 5.6 Aura Feed (Full Screen / Dedicated Tab)
- Filter tabs at top: All / Friends / Battles / Groups
- Infinite scroll, cards as described in 5.4
- Pull-to-refresh with a custom orb-spin loading animation

### 5.7 Leaderboard Screen
- Tab bar: Friends / School / City
- Each row: rank number, profile photo, username, score, 24hr change arrow
- Top 3 get special visual treatment (subtle glow/crown icon, not gaudy)
- Your own row is pinned/highlighted if you scroll past your rank

### 5.8 Profile Screen (Own + Others')
- Top: Orb visual (color = current standing), username, score
- Score history line graph (last 30 days)
- "Top Moments" section — your 3 highest and 3 lowest transactions ever, shown as mini cards
- Share button prominently placed — generates the Aura Card
- If viewing a friend's profile: "Send Aura" button replaces edit options

### 5.9 Aura Card Export Screen
- Pre-built templates (2–3 layout options): score-focused, top-moment-focused, rank-focused
- Live preview updates as user picks template
- One-tap export buttons: Instagram Stories, TikTok, Snapchat, Save to Camera Roll
- All templates carry a subtle Aura watermark/logo for organic brand spread

### 5.10 Notifications
- Real-time push, written in casual slang tone (see Section 8.3)
- Tapping a notification deep-links directly to that specific transaction in the feed

### 5.11 Settings
- Privacy: who can send you aura, leaderboard visibility, block/mute list
- Notifications: granular toggles (transactions, reactions, streak reminders, leaderboard rank changes)
- Account: linked socials, phone number, delete account
- About: version, terms, support contact

---

## 6. Design System

### 6.1 Overall Theme
Dark mode by default — Gen Z strongly prefers dark UI, it reads as more premium and "mysterious," and it fits the "aura energy" concept far better than a bright white app would.

### 6.2 Color Palette
- **Background base**: `#0a0a0a` (near-black)
- **Surface/card background**: `#141414` with subtle `#ffffff` border at 6–8% opacity (glassmorphism feel)
- **Primary accent (positive aura)**: teal-emerald gradient — `#14b88a` → `#053d2c`
- **Secondary accent (negative aura)**: warm coral — `#fb7360` (used sparingly, only for negative point values and error states — keeps the palette to essentially two hues total)
- **Text primary**: `#f4f4f5`
- **Text secondary/muted**: `#a1a1aa`
- **Highlight/premium accent** (streaks, top 3 leaderboard, premium features): soft gold `#d4af37`, used very sparingly so it retains meaning

### 6.3 Typography
- **Primary typeface**: Rounded sans-serif (SF Pro Rounded, or Poppins/Nunito as cross-platform equivalents)
- **Score numbers**: Extra bold weight, large size (48–64px on home screen), should feel "bouncy" and alive
- **Body text**: Regular weight, 14–16px
- **UI copy voice**: lowercase-first styling throughout the interface (e.g., "send aura," not "Send Aura") — reads more casual and native to the audience
- **Letter spacing**: slightly tight on headers for a modern feel, normal on body text for readability

### 6.4 Iconography
- Custom icon set, rounded/soft edges (not sharp corporate icons)
- The orb motif should recur subtly across icons (loading spinners, empty states, achievement badges)

### 6.5 Motion & Interaction Design
- **Score changes**: always animate as a count-up/count-down over ~0.6–1 second, never a hard cut
- **Orb**: subtle idle pulse animation at all times; more dramatic glow/flare when score changes significantly
- **Haptic feedback**: light haptic on every send, stronger haptic on receiving a large positive or negative transaction
- **Positive transaction feedback**: brief particle/confetti burst in teal tones
- **Negative transaction feedback**: subtle screen-dim or "crack" visual effect, kept tasteful and not mean-spirited
- **Page transitions**: soft slide/fade, avoid harsh instant cuts
- **Loading states**: custom orb-spin animation instead of generic spinners

### 6.6 Component Style
- Rounded corners throughout: 16–24px radius on cards, 999px (full pill) on buttons and chips
- Generous padding and whitespace between feed cards to avoid visual clutter
- Glassmorphic blur on modals and bottom sheets (frosted dark background effect)
- Buttons: solid teal gradient fill for primary actions, outlined/ghost style for secondary actions

### 6.7 Empty States
- Every empty state (no friends yet, no transactions yet, empty leaderboard) should have custom illustration + a playful, encouraging line of copy rather than a generic "no data" message

---

## 7. Content & Copy Strategy

### 7.1 Voice & Tone Principles
- Casual, funny, slightly chaotic — written like a Gen Z friend group text, not a corporate app
- Lowercase styling in UI copy
- Use of emoji is expected and encouraged in notifications and confirmations, but not overused to the point of feeling try-hard
- Self-aware humor about the app's own mechanic (e.g., acknowledging that losing aura "hurts" in a jokey way) builds trust and relatability

### 7.2 Preset "Moment Chip" Library (Starter Set)
**Positive moment chips:**
- "clutch save"
- "showed up for me"
- "main character energy"
- "carried the group project"
- "paid without being asked"
- "gave the best advice"
- "just built different"
- "certified real one"

**Negative moment chips:**
- "left me on read"
- "ick moment"
- "flaked last minute"
- "started drama for no reason"
- "forgot my birthday"
- "copied my outfit and denied it"
- "ghosted the group chat"
- "menace behavior"

(Chips should be refreshed/rotated periodically based on trending slang — this list needs a lightweight CMS so it can be updated without an app store release.)

### 7.3 Notification Copy Examples
- "bro just cooked you 💀 -80 aura from @username"
- "you're up 120 aura today. certified main character."
- "@username just called you out. defend yourself 👀"
- "your aura is decaying... open the app before it's too late"
- "you just broke into the top 10 on your school leaderboard 🔥"

### 7.4 Onboarding Copy (Full Draft)
1. "your friends already judge you. now it's official."
2. "send aura for the wins. take it for the fails."
3. "flex your score. or keep it private. your call."
4. "let's find your friends already on aura" (contacts permission)

---

## 8. Growth & Virality Strategy

### 8.1 Core Growth Loop
1. User A sends User B an aura transaction
2. User B gets a notification, opens the app, sees their score change
3. User B is prompted to react or respond (send aura back)
4. Either user shares an Aura Card externally (Stories/TikTok)
5. External viewers see the card, are curious, download the app
6. New user syncs contacts, finds existing friends already on the app, starts sending aura immediately

### 8.2 Launch Strategy
- Seed the app inside a small number of tightly connected friend groups/schools first (not a broad public launch) — social apps grow through dense local networks, not broad thin ones
- Partner with a handful of micro-influencers/creators in the Gen Z space to post organic "I made my friends rate my aura" content — this format is inherently entertaining and needs no paid ad framing
- Encourage the "Aura Battle" and "Wrapped" features specifically as TikTok-native content formats

### 8.3 Retention Loops
- Decay mechanic creates daily-open pressure
- Streaks create friend-specific daily interaction pressure
- Leaderboard rank changes create curiosity-driven re-opens
- Push notifications are written to create curiosity/FOMO, not just inform

---

## 9. Monetization Strategy

### 9.1 Principles
- Cosmetic and convenience monetization performs far better with this audience than feature-gating — never paywall the core social loop (sending/receiving aura, leaderboards, feed)
- Rewarded ads (opt-in, for a clear benefit like a streak freeze or boost) outperform forced interstitials with this demographic

### 9.2 Revenue Streams
| Stream | Description | Price Point Guidance |
|---|---|---|
| Aura Boosts | Temporary 2x point multiplier | Rewarded ad (free) or $0.99 IAP |
| Streak Freeze | Protects a streak for 1 day | $0.99 or earned via engagement |
| Orb Skins | Cosmetic profile orb themes | $1.99–$4.99, seasonal drops |
| Private Groups | Closed smaller leaderboards | Part of subscription tier |
| Aura+ Subscription | Ad-free, unlimited custom point values, exclusive skins, early access to new features | $4.99/month or $29.99/year |
| Limited Drops | Seasonal/event-based cosmetic items | $2.99–$9.99, time-limited to drive urgency |

### 9.3 Monetization Rollout Timing
- Do NOT introduce monetization at launch — the first 2–3 months should be entirely focused on growth and retention loop validation
- Introduce cosmetics first (lowest friction, purely optional)
- Introduce subscription tier only after a clear engaged user base exists (suggest waiting for meaningful daily active usage before this step)

---

## 10. Safety, Trust & Moderation (Critical — Do Not Skip)

Because this app is fundamentally about social judgment, safety design is not optional polish — it needs to be built into the core loop from day one.

- **Point limits by default**: cap negative transactions lower than positive ones by default (e.g., -300 max vs +500 max) to reduce potential for pile-on harassment
- **Rate limiting**: cap how many negative transactions one user can send to a single other user in a given time window, to prevent targeted harassment
- **Reporting**: every transaction must be reportable with one tap; reported content should be reviewed quickly
- **Blocking**: users can block others from sending them aura at all, and blocking is fully silent (no notification to the blocked user)
- **Word filtering**: custom text reasons should be filtered for slurs, harassment, and self-harm language, with automatic flagging for review
- **Minor safety**: age-gate at signup, and if users under 18 are supported, defaults should be more conservative (e.g., public leaderboards off by default, negative point caps lower)
- **Opt-out of public visibility**: a user should always be able to fully privatize their score and never appear on any public leaderboard
- **No permanent public shame loop**: consider allowing users to "clear" or archive old negative transactions from their own visible history after a period of time, so the app doesn't become a permanent record of someone's worst moments

---

## 11. Suggested Tech Stack (High-Level)

- **Mobile**: React Native or Flutter for cross-platform speed (single codebase for iOS + Android, important for a lean early team)
- **Backend**: Node.js or similar, with a real-time layer (e.g., WebSockets or a managed real-time database) to support live score updates and feed refresh
- **Database**: PostgreSQL for relational data (users, transactions, friendships) + Redis for leaderboard caching/real-time rank calculations
- **Push notifications**: Firebase Cloud Messaging (cross-platform)
- **Image/card generation**: Server-side or on-device rendering for the Aura Card export feature (on-device is faster and cheaper at scale)
- **Analytics**: Event-based analytics (Mixpanel/Amplitude style) tracking every core loop step, from install → contact sync → first transaction sent → first share

---

## 12. Roadmap & Timeline

| Phase | Timeframe | Focus |
|---|---|---|
| Phase 0 | Weeks 1–2 | Finalize design system, wireframes, backend architecture |
| Phase 1 (MVP Build) | Weeks 3–8 | Core loop: auth, send aura, score, feed, leaderboard, basic sharing |
| Phase 1.5 (Closed Beta) | Weeks 9–10 | Seed into 2–3 friend groups/one school, gather feedback, fix core bugs |
| Phase 2 (Growth Features) | Weeks 11–16 | Decay, streaks, school/city leaderboards, call-outs, battles |
| Phase 2.5 (Public Launch) | Week 16+ | Broader rollout, influencer seeding push |
| Phase 3 (Monetization) | Months 4–6 | Cosmetics, boosts, subscription tier |
| Phase 4 (Wrapped + Marketplace) | Months 6+ | Recap features, seasonal drops, deeper retention systems |

---

## 13. Key Metrics to Track

- **D1/D7/D30 retention** — core measure of whether the loop is sticky
- **Transactions sent per active user per day** — measures core engagement depth
- **Share rate** — % of users who export at least one Aura Card per week (this is your growth engine, track it closely)
- **K-factor / viral coefficient** — how many new installs each existing user generates through sharing
- **Contact sync completion rate** — critical for friend-graph density at signup
- **Streak participation rate** — % of active users with at least one active streak
- **Report/block rate** — safety health indicator, should be monitored closely as the app scales

---

## 14. Summary

Aura succeeds if three things are true simultaneously:
1. The core loop (send/receive aura) is fast, fun, and low-friction
2. Every meaningful moment in the app produces something worth sharing outside the app
3. Safety rails prevent the app's core mechanic from tipping into harassment

Everything in this plan — the decay mechanic, the streaks, the Aura Cards, the Wrapped feature, the color system, the copy voice — is designed to reinforce those three pillars at once.
