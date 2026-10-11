# Glossary

- **Aura score** — running social score, initialized to 1000.
- **Username claim** — permanent `usernames/{username}` document mapping a handle
  to its uid. Never reassigned.
- **Public profile** — `publicProfiles/{uid}`, the handle-and-photo-only document
  that discovery is allowed to read. Deliberately carries no score.
- **Pair id** — a friendship's document id: the two uids sorted and joined with
  `_`. Derived on both the client and in the security rules, which must agree.
- **Pending / accepted** — the only two friendship states. Decline, cancel and
  unfriend are all a delete; there is no stored `declined`.
- **Minor** — account conservatively evaluated as under 18 from birth year.
- **Orb** — score-driven visual and current fallback avatar.
- **Spark / Blaze** — Firebase's free and paid plans. Spark means no Cloud
  Functions and no Cloud Storage, which shapes most open questions.
