---
task-id: 2026-10-11-separate-backend-folder
flow: REFACTOR
status: DONE
started: 2026-10-11
completed: 2026-10-11
---

# Task: Move the backend outside the Flutter app folder

## Flow: REFACTOR

## Brainstorm
N/A (REFACTOR — no brainstorm)

## Plan
- [x] Run the existing backend tests as a baseline, then move the complete `app/backend/` directory to `backend/` at the Aura project root, preserving source, tests, lockfile, installed dependencies and local cache.
- [x] Update the backend README and current wiki references to the new location; add a backend `.gitignore` covering dependencies, cache, logs, environment files and service-account credentials because `app/.gitignore` will no longer cover it.
- [x] Run the backend tests from the new folder, check imports/startup and verify the old folder is absent. Preserve the app's API URL and existing behavior.
- [x] Security gate — PASSED
- [x] Code review — APPROVED
- [x] Verification — PASSED

## Implementation Notes
### Impact Analysis
- Directory: `D:/Project/Aura/app/backend` -> `D:/Project/Aura/backend`.
- Documentation: `backend/README.md`, wiki `architecture.md`, `features/node-backend.md`, `api-contracts.md`; add a structural decision and update the wiki index if necessary.
- Tests: existing `backend/test/*.test.js`, run with the existing `npm test` script.
- Flutter communicates over HTTP; the file move does not change its API base URL.
- Public API surface changed: NO. Database queries affected: NO.
- Security controls: preserve Firebase token verification, privileged credentials outside the repository, loopback binding, validation and transaction protections.
- Git metadata currently exists only at `app/.git`. Keep it in place for this folder move. The backend will be outside that repository after the move; unifying repository tracking is a separate decision. Current app status lists backend and app files as untracked.
- Move the existing folder rather than recreate the server because this preserves all files and avoids changing runtime behavior.
- Historical task records remain historical; update current run instructions and wiki paths only.

## Security Gate
Status: PASSED
- Source SHA256 hashes match the pre-move files: authentication, authorization,
  validation, rate limits, loopback binding and privileged credential handling unchanged.
- Added backend ignore rules equivalent to the relevant app rules.
- No new runtime patterns, dependencies or secrets introduced.
- Blocking findings: none. Warnings: none.

## Code Review
Status: APPROVED
- All 11 existing tests pass before and after moving.
- All seven source/test files plus package.json and package-lock.json retain their hashes.
- README and current wiki no longer reference app/backend.
- Backend and Flutter app now have separate sibling directories.
- No runtime code, API URLs, dependencies or Git metadata changed.
- Initial hash check used paths relative to the wrong working directory;
  corrected and reran it successfully before approving the review.

## Verification
Status: PASSED
Command: npm test (in D:/Project/Aura/backend)
Exit code: 0
Observed output:
```text
tests 11
pass 11
fail 0
skipped 0
Backend imports OK
Directory separation OK
```
Baseline: 11 passed, 0 failed. Restricted execution first blocked loopback
connections with EACCES; approved execution with local networking passed.
Fresh final execution after security/review also passed all 11 tests.
Import smoke check: Firebase Admin modules and local HTTP module load from the
new folder. Original backend directory is absent. Production credential-backed
server startup was not exercised; runtime code and credentials are unchanged.
Wiki updated: architecture, features/node-backend, api-contracts, decisions.

## Final Status: DONE
Duration: approximately 4 minutes.
