# Local Node.js Aura API

Added 2026-10-04. Task: [spark-node-backend](../../../tasks/2026-10-04-spark-node-backend.md).

Firebase Auth and Firestore remain on Spark. The Flutter send screen calls
`POST /v1/aura` on a Node.js server running on the development computer. The
server verifies the Firebase ID token and uses the Admin SDK to commit one aura
transaction, the recipient score change, sender/recipient feed copies, and
rate-limit state atomically. Retries use an idempotency key.

The account-deletion flow calls the authenticated purge endpoint first. It
requires sign-in within the last five minutes. It
marks the account as deleting, prevents concurrent sends, and removes aura
records, counterparty feed copies and rate-limit records before the existing
profile and Auth cleanup proceeds.

The app's direct Firestore client cannot write scores, transactions, feeds, or
rate-limit records. The Admin SDK bypasses those rules and is therefore held
only on the computer, with its service-account key outside the repository.

This local setup is not an always-on beta backend. A future deployment needs
HTTPS and its own hosting arrangement. Friends-circle feed fan-out, reactions,
leaderboard reads and push remain later slices. The small custom-text denylist
also needs a reviewed filter and auto-flagging before beta.

## Sources

- Code: `backend/src/`, `app/lib/features/send/`, `app/firestore.rules`
- Run guide: `backend/README.md`
