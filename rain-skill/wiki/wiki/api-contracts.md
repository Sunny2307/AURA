# API Contracts

The app uses Firebase Auth and Firestore SDK contracts for signup, friends and
safety. A local Node.js server now exposes one custom HTTP endpoint for aura.

## `POST /v1/aura`

Requires a Firebase ID token in `Authorization: Bearer`. JSON body:
`recipientUid`, integer `points`, `reason` (1–80 characters), `visibility`
(`private` or `friends`), UUID `idempotencyKey`, and optional matching `chipId`.
Returns 201 for a new send or 200 for an identical retry, with `id` and
`recipientScore`. Errors use `{ "error": { "code", "message" } }`.

The server requires an accepted friendship, no block in either direction,
recipient availability, sender point caps and send limits. It commits the
recipient score and records atomically. See [[features/node-backend]].

`GET /health` reports whether the local HTTP process is listening. It does not
prove Firebase credentials or Firestore connectivity.

`DELETE /v1/me/aura-data` requires a Firebase ID token with `auth_time` within
the last five minutes (otherwise `RECENT_LOGIN_REQUIRED`) and removes the
authenticated account's aura history before the existing account deletion flow.

## Sources

- Code: `app/lib/features/auth/data/`
- Code: `backend/src/`, `app/lib/features/send/data/aura_api.dart`
