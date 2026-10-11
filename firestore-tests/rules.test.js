/**
 * Security-rules tests for Aura.
 *
 * These do not test the app. They test what the *backend* permits when the app
 * is not in the loop at all — the case where someone has decompiled the APK, or
 * is simply driving the Firestore REST API with their own valid ID token. Every
 * `assertFails` below is an attack that would otherwise work.
 *
 * Run with `npm test` in this folder. That wraps the run in
 * `firebase emulators:exec`, so the tests never touch the live project. Pointing
 * them at production would be both destructive and meaningless — rules tests need
 * to create documents that violate the rules, and the emulator lets them try.
 */

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

/** The year the emulator will stamp on `request.time`. */
const THIS_YEAR = new Date().getFullYear();

/**
 * Birth years chosen relative to the current year rather than hard-coded, so
 * these tests do not silently start passing for the wrong reason in January.
 *
 * The gate is conservative: age = year - birthYear - 1. So "adult" needs a gap
 * of at least 19, and a minor who is old enough to join needs 16-18.
 */
const ADULT_BIRTH_YEAR = THIS_YEAR - 25;
const MINOR_BIRTH_YEAR = THIS_YEAR - 17; // → 16, old enough, still a minor
const TOO_YOUNG_BIRTH_YEAR = THIS_YEAR - 13; // → 12

let testEnv;

/** A well-formed create payload. Individual tests override single fields. */
function newUser(overrides = {}) {
  const birthYear = overrides.birthYear ?? ADULT_BIRTH_YEAR;
  const isMinor = overrides.isMinor ?? THIS_YEAR - birthYear - 1 < 18;
  return {
    username: 'samjones',
    photoUrl: null,
    score: 1000,
    birthYear,
    isMinor,
    privacy: {
      whoCanSendAura: 'friends',
      appearOnLeaderboards: !isMinor,
    },
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

/**
 * Seeds a document bypassing the rules, so a test can start from a state that
 * legitimately exists (an already-created user, a claimed username) without
 * asserting anything about how it got there.
 */
async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

/**
 * Commits the three documents an account is made of, exactly as the app does:
 * the private profile, the permanent handle claim, and the public discovery
 * profile. Each one's rule requires the other two, so anything less fails.
 *
 * `claim` lets a test deliberately break one of the three — a claim pointing at
 * the wrong uid, a public profile under a different handle, or none at all.
 */
function createAccount(db, uid, data = newUser(), claim = {}) {
  const claimUsername = claim.username ?? data.username;
  const claimUid = claim.uid ?? uid;
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), data);
  batch.set(doc(db, `usernames/${claimUsername}`), { uid: claimUid });
  if (!claim.omitPublicProfile) {
    batch.set(doc(db, `publicProfiles/${claim.publicUid ?? uid}`), {
      username: claim.publicUsername ?? data.username,
      photoUrl: data.photoUrl ?? null,
    });
  }
  return batch.commit();
}

/**
 * An account that already exists, written past the rules. Friendship tests care
 * about what two established users can do to each other, not about how they
 * signed up — that is covered exhaustively above.
 */
async function seedAccount(uid, username = uid) {
  await seed(`users/${uid}`, newUser({ username }));
  await seed(`usernames/${username}`, { uid });
  await seed(`publicProfiles/${uid}`, { username, photoUrl: null });
}

/** The document id for a friendship, derived the same way the client derives it. */
function pairId(a, b) {
  return [a, b].sort().join('_');
}

/** A well-formed pending friend request from `from` to `to`. */
function newRequest(from, to, overrides = {}) {
  return {
    members: [from, to].sort(),
    requestedBy: from,
    status: 'pending',
    createdAt: serverTimestamp(),
    respondedAt: null,
    ...overrides,
  };
}

/** Puts an existing block into the database, bypassing the rules. */
async function seedBlock(blockerUid, blockedUid) {
  await seed(`users/${blockerUid}/blocks/${blockedUid}`, {
    createdAt: new Date(),
  });
}

/** Puts an existing friendship into the database, bypassing the rules. */
async function seedFriendship(from, to, overrides = {}) {
  await seed(`friendships/${pairId(from, to)}`, {
    members: [from, to].sort(),
    requestedBy: from,
    status: 'pending',
    createdAt: new Date(),
    respondedAt: null,
    ...overrides,
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'aura-d68c3',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('users/{uid} — the score is not the client\'s to set', () => {
  it('creates an account with the pinned starting score', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(createAccount(db, 'alice'));
  });

  it('refuses an account that starts rich', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser({ score: 1_000_000 })),
    );
  });

  it('refuses an account that starts one point above the baseline', async () => {
    // The off-by-one matters: a rule written as `score <= 1000` would let a
    // client start at 999 and look humble while still being wrong. This proves
    // the check is equality, in both directions.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(createAccount(db, 'alice', newUser({ score: 1001 })));
    await assertFails(createAccount(db, 'alice', newUser({ score: 999 })));
  });

  it('refuses to raise its own score after create', async () => {
    // The headline attack. Someone with a valid token editing their own document.
    await seed('users/alice', newUser());
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/alice'), { score: 99_999 }));
  });

  it('refuses to nudge its own score by a single point', async () => {
    await seed('users/alice', newUser());
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/alice'), { score: 1001 }));
  });

  it('refuses to lower someone else\'s score', async () => {
    await seed('users/bob', newUser({ username: 'bob' }));
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/bob'), { score: 0 }));
  });

  // `friendCount` was removed from the model in slice 2 — it is now derived from
  // the friendships collection. These two cases are kept, using that field name
  // on purpose: they now prove the *general* protection, which is that a field
  // the schema does not know about cannot be smuggled in. Before, they only
  // proved a rule about one specific field.
  it('refuses to add an unknown field on update', async () => {
    await seed('users/alice', newUser());
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/alice'), { friendCount: 5000 }));
  });

  it('refuses a create carrying an unknown field', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(createAccount(db, 'alice', newUser({ friendCount: 12 })));
  });
});

describe('users/{uid} — you are only yourself', () => {
  it('refuses to create a document under another uid', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'bob', newUser({ username: 'bob' })),
    );
  });

  it('refuses a create from an unauthenticated caller', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(createAccount(db, 'alice'));
  });

  it('refuses a signed-in user reading another private profile', async () => {
    await seed('users/bob', newUser({ username: 'bob' }));
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'users/bob')));
  });

  it('lets a signed-in user read their own profile', async () => {
    await seed('users/alice', newUser());
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(getDoc(doc(db, 'users/alice')));
  });

  it('refuses profile reads to unauthenticated callers', async () => {
    // Stops the whole user table being scraped without burning an account.
    await seed('users/bob', newUser({ username: 'bob' }));
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users/bob')));
  });

  it('refuses deleting the private profile on its own', async () => {
    // Was 'refuses account self-deletion' until slice 9, when deletion became
    // possible — the Cloud Function it was waiting for is not coming on the
    // Spark plan, and shipping a beta to minors with no way to leave was not
    // acceptable. What the rule stops now is a *partial* delete: this document
    // may only go if the public profile goes with it, or a searchable handle
    // would be left belonging to nobody. The full path is covered in the
    // account-deletion suite below.
    //
    // Seeds a *complete* account on purpose. With only the user document
    // present, `!existsAfter(publicProfiles/alice)` is trivially true and the
    // delete is allowed — which is the right behaviour for cleaning up a
    // half-created account, and not what this test is about.
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteDoc(doc(db, 'users/alice')));
  });
});

describe('users/{uid} — age and minor safety', () => {
  it('refuses an account below the minimum age', async () => {
    const db = testEnv.authenticatedContext('kid').firestore();
    await assertFails(
      createAccount(db, 'kid', newUser({ birthYear: TOO_YOUNG_BIRTH_YEAR })),
    );
  });

  it('refuses an implausible birth year', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(createAccount(db, 'alice', newUser({ birthYear: 3000 })));
    await assertFails(createAccount(db, 'alice', newUser({ birthYear: 1099 })));
  });

  it('refuses a minor claiming to be an adult', async () => {
    // Without the consistency check this is how a 16-year-old awards themselves
    // adult point caps and a public leaderboard slot.
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertFails(
      createAccount(
        db,
        'teen',
        newUser({
          birthYear: MINOR_BIRTH_YEAR,
          isMinor: false,
          privacy: { whoCanSendAura: 'friends', appearOnLeaderboards: true },
        }),
      ),
    );
  });

  it('creates a minor account with leaderboards off', async () => {
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertSucceeds(
      createAccount(db, 'teen', newUser({ birthYear: MINOR_BIRTH_YEAR })),
    );
  });

  it('refuses a minor account that asks to appear on leaderboards', async () => {
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertFails(
      createAccount(
        db,
        'teen',
        newUser({
          birthYear: MINOR_BIRTH_YEAR,
          isMinor: true,
          privacy: { whoCanSendAura: 'friends', appearOnLeaderboards: true },
        }),
      ),
    );
  });

  it('refuses a minor switching leaderboards on later', async () => {
    // The create-time check is not enough on its own — a settings screen, or a
    // raw API call, would otherwise flip it the day after signup.
    await seed('users/teen', newUser({ birthYear: MINOR_BIRTH_YEAR }));
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/teen'), {
        privacy: { whoCanSendAura: 'friends', appearOnLeaderboards: true },
      }),
    );
  });

  it('refuses flipping isMinor after create', async () => {
    await seed('users/teen', newUser({ birthYear: MINOR_BIRTH_YEAR }));
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertFails(updateDoc(doc(db, 'users/teen'), { isMinor: false }));
  });

  it('refuses rewriting birthYear after create', async () => {
    await seed('users/teen', newUser({ birthYear: MINOR_BIRTH_YEAR }));
    const db = testEnv.authenticatedContext('teen').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/teen'), { birthYear: ADULT_BIRTH_YEAR }),
    );
  });
});

describe('users/{uid} — the writable surface is exactly photo and privacy', () => {
  beforeEach(async () => {
    await seed('users/alice', newUser());
  });

  // Was 'allows a photo change' until the slice 2 security review. An arbitrary
  // URL here is now refused outright — see the photoUrl suite below for why, and
  // `isAllowedPhotoUrl` in the rules for what replaces this when Cloud Storage
  // exists. `photoUrl` is still a writable key; its accepted values shrank.
  it('refuses an arbitrary photo url, but keeps photoUrl writable', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/alice'), { photoUrl: 'https://example.com/a.jpg' }),
    );
    await assertSucceeds(
      updateDoc(doc(db, 'users/alice'), { photoUrl: null }),
    );
  });

  it('allows a privacy change an adult is entitled to', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users/alice'), {
        privacy: { whoCanSendAura: 'nobody', appearOnLeaderboards: false },
      }),
    );
  });

  it('refuses an unknown privacy value', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/alice'), {
        privacy: { whoCanSendAura: 'anyone_at_all', appearOnLeaderboards: false },
      }),
    );
  });

  it('refuses a username change', async () => {
    // Would orphan the usernames/{name} claim and break historical mentions.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/alice'), { username: 'someoneelse' }));
  });

  it('refuses a smuggled field alongside a legitimate one', async () => {
    // The realistic shape of the attack: a valid photo change with `score`
    // riding along in the same write, hoping the rule only checks the field it
    // was written for.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/alice'), {
        photoUrl: 'https://example.com/a.jpg',
        score: 5000,
      }),
    );
  });

  it('refuses an entirely new field', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'users/alice'), { isVerified: true }));
  });
});

describe('users/{uid} — username shape is enforced server-side too', () => {
  const rejected = {
    'too short': 'ab',
    'starts with a digit': '1sam',
    'starts with an underscore': '_sam',
    'uppercase': 'SamJones',
    'a space': 'sam jones',
    'unicode homoglyph': 'pаul',
    'double underscore': 'sam__jones',
    'trailing underscore': 'samjones_',
    'over the length limit': 'a'.repeat(21),
  };

  for (const [why, username] of Object.entries(rejected)) {
    it(`refuses a username with ${why}`, async () => {
      const db = testEnv.authenticatedContext('alice').firestore();
      await assertFails(
        createAccount(db, 'alice', newUser({ username }), { username }),
      );
    });
  }
});

describe('usernames/{username} — claimable once, never reassigned', () => {
  it('creates a profile and matching claim atomically', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(createAccount(db, 'alice'));
  });

  it('refuses a standalone permanent handle claim', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'usernames/samjones'), { uid: 'alice' }));
  });

  it('refuses a profile without its matching claim', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'users/alice'), newUser()));
  });

  it('refuses an atomic pair whose claim points at a different uid', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(createAccount(db, 'alice', newUser(), { uid: 'bob' }));
  });

  it('refuses an atomic pair whose claim has a different username', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser(), { username: 'othername' }),
    );
  });

  it('is readable while signed out', async () => {
    // Deliberate: the signup availability check runs before the account exists.
    await seed('usernames/samjones', { uid: 'alice' });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, 'usernames/samjones')));
  });

  it('refuses bulk username enumeration', async () => {
    await seed('usernames/samjones', { uid: 'alice' });
    const signedOut = testEnv.unauthenticatedContext().firestore();
    const signedIn = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDocs(collection(signedOut, 'usernames')));
    await assertFails(getDocs(collection(signedIn, 'usernames')));
  });

  it('refuses a claim pointing at someone else', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'usernames/samjones'), { uid: 'bob' }));
  });

  it('refuses a claim from an unauthenticated caller', async () => {
    // Otherwise every good handle could be squatted before launch by a script
    // with no account at all.
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'usernames/samjones'), { uid: 'alice' }));
  });

  it('refuses stealing a handle someone already holds', async () => {
    await seed('usernames/samjones', { uid: 'alice' });
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(setDoc(doc(db, 'usernames/samjones'), { uid: 'bob' }));
  });

  it('refuses reassigning a handle, even by its owner', async () => {
    await seed('usernames/samjones', { uid: 'alice' });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'usernames/samjones'), { uid: 'bob' }));
  });

  it('refuses releasing a handle by deleting the claim', async () => {
    // Freeing it would let someone squat a name the moment its owner churned,
    // and old mentions would quietly start pointing at a different person.
    await seed('usernames/samjones', { uid: 'alice' });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteDoc(doc(db, 'usernames/samjones')));
  });

  it('refuses a claim carrying extra fields', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'usernames/samjones'), { uid: 'alice', score: 9999 }),
    );
  });

  it('refuses claiming a malformed handle', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'usernames/Sam'), { uid: 'alice' }));
    await assertFails(setDoc(doc(db, 'usernames/ab'), { uid: 'alice' }));
  });
});

describe('publicProfiles/{uid} — discovery without exposure', () => {
  it('refuses an account created without its public profile', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser(), { omitPublicProfile: true }),
    );
  });

  it('refuses a public profile claiming a handle the user does not own', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser(), { publicUsername: 'someoneelse' }),
    );
  });

  it('refuses a public profile created under another uid', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser(), { publicUid: 'bob' }),
    );
  });

  it('refuses a standalone public profile with no account behind it', async () => {
    // The impersonation case. If this were allowed, anyone could publish a
    // profile claiming any handle and every search for it would find them.
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      setDoc(doc(db, 'publicProfiles/mallory'), {
        username: 'samjones',
        photoUrl: null,
      }),
    );
  });

  it('lets any signed-in user read a public profile', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(getDoc(doc(db, 'publicProfiles/alice')));
  });

  it('refuses a signed-out read', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'publicProfiles/alice')));
  });

  it('refuses enumerating every user', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDocs(collection(db, 'publicProfiles')));
  });

  it('lets the owner touch their photo field, within the allowed values', async () => {
    // Narrowed by the slice 2 security review: the owner still owns this field,
    // but an arbitrary URL is no longer one of its legal values.
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'publicProfiles/alice'), { photoUrl: null }),
    );
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), {
        photoUrl: 'https://example.test/a.jpg',
      }),
    );
  });

  it('refuses changing the handle on the public profile', async () => {
    // Would orphan the permanent usernames/{name} claim.
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), { username: 'somebodyelse' }),
    );
  });

  it('refuses editing someone else\'s public profile', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), { photoUrl: 'https://x.test/x.jpg' }),
    );
  });

  it('refuses smuggling a score onto the public profile', async () => {
    // The reason score is not in this document at all: it is client-written.
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), { score: 999999 }),
    );
  });
});

describe('friendships/{pairId} — consent, stored once', () => {
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  it('lets someone send a friend request', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob')),
    );
  });

  it('refuses a request sent on someone else\'s behalf', async () => {
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob')),
    );
  });

  it('refuses a request whose requestedBy is not the sender', async () => {
    // Would let alice manufacture a request that looks like bob sent it, so
    // that accepting it falls to her and bob never consented to anything.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob', { requestedBy: 'bob' })),
    );
  });

  it('refuses a document id that does not match its members', async () => {
    // Without the id check, a second competing friendship document could exist
    // for the same pair under an arbitrary id.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'friendships/whatever_i_like'),
        newRequest('alice', 'bob')),
    );
  });

  it('refuses unsorted members', async () => {
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      setDoc(doc(db, 'friendships/bob_alice'), {
        members: ['bob', 'alice'],
        requestedBy: 'bob',
        status: 'pending',
        createdAt: serverTimestamp(),
        respondedAt: null,
      }),
    );
  });

  it('refuses befriending yourself', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'friendships/alice_alice'), {
        members: ['alice', 'alice'],
        requestedBy: 'alice',
        status: 'pending',
        createdAt: serverTimestamp(),
        respondedAt: null,
      }),
    );
  });

  it('refuses a request to a uid with no account', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'ghost')}`),
        newRequest('alice', 'ghost')),
    );
  });

  it('refuses creating a friendship that is already accepted', async () => {
    // The whole point of request-then-accept: nobody starts out accepted.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob', { status: 'accepted' })),
    );
  });

  it('refuses a backdated createdAt', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob', { createdAt: new Date(0) })),
    );
  });

  it('refuses an unknown field', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob', { score: 5000 })),
    );
  });

  it('lets the recipient accept', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses the sender accepting their own request', async () => {
    // The consent rule. Without it the request/accept model is theatre: alice
    // could add herself to bob's friend list unilaterally.
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses a stranger accepting', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses rewriting the members on accept', async () => {
    // Would let bob redirect an accepted friendship onto a third party.
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
        members: ['bob', 'mallory'],
      }),
    );
  });

  it('refuses rewriting requestedBy on accept', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
        requestedBy: 'bob',
      }),
    );
  });

  it('refuses re-accepting an already accepted friendship', async () => {
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses reverting an accepted friendship to pending', async () => {
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'pending',
      }),
    );
  });

  it('refuses a backdated respondedAt', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: new Date(0),
      }),
    );
  });

  it('lets the sender cancel', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('lets the recipient decline', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('lets either side unfriend after accepting', async () => {
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('refuses a stranger deleting a friendship', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('lets a member read their own friendship', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      getDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('refuses a stranger reading a friendship', async () => {
    await seedFriendship('alice', 'bob');
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      getDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });
});

describe('friendships — the friend-list query the app actually runs', () => {
  // The plan flagged this as the one thing that had to be proven rather than
  // assumed: that a membership-scoped `array-contains` list query is accepted
  // by a rule written against `resource.data.members`. If it is not, the whole
  // single-document friendship design needs rethinking, so it gets its own
  // suite rather than being buried as an afterthought.
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
    await seedAccount('carol', 'carol');
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    await seedFriendship('bob', 'carol');
  });

  it('allows the accepted-friends query scoped to yourself', async () => {
    const db = testEnv.authenticatedContext('bob').firestore();
    const snapshot = await assertSucceeds(
      getDocs(query(
        collection(db, 'friendships'),
        where('members', 'array-contains', 'bob'),
        where('status', '==', 'accepted'),
      )),
    );
    assert.equal(snapshot.size, 1);
    assert.equal(snapshot.docs[0].id, pairId('alice', 'bob'));
  });

  it('allows the pending-requests query scoped to yourself', async () => {
    const db = testEnv.authenticatedContext('bob').firestore();
    const snapshot = await assertSucceeds(
      getDocs(query(
        collection(db, 'friendships'),
        where('members', 'array-contains', 'bob'),
        where('status', '==', 'pending'),
      )),
    );
    assert.equal(snapshot.size, 1);
    assert.equal(snapshot.docs[0].id, pairId('bob', 'carol'));
  });

  it('refuses an unscoped query over everyone\'s friendships', async () => {
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDocs(collection(db, 'friendships')));
  });

  it('refuses querying someone else\'s friendships', async () => {
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      getDocs(query(
        collection(db, 'friendships'),
        where('members', 'array-contains', 'alice'),
      )),
    );
  });
});

describe('photoUrl — the beacon the slice 2 review found', () => {
  // Background: publicProfiles is readable by every signed-in user, and the
  // friends screen renders a pending request's photo before any accept. An
  // arbitrary URL there is a zero-interaction IP/location/timing beacon fired
  // by sending an unsolicited friend request. Cloud Storage does not exist on
  // the Spark plan, so the honest constraint is "no photo at all".
  it('refuses an arbitrary photo url on the public profile', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), {
        photoUrl: 'https://attacker.test/b.png?t=alice',
      }),
    );
  });

  it('refuses a file:// photo url', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), {
        photoUrl: 'file:///etc/passwd',
      }),
    );
  });

  it('refuses a very long photo url', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles/alice'), {
        photoUrl: 'https://attacker.test/'.padEnd(50000, 'a'),
      }),
    );
  });

  it('still allows clearing the photo to null', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'publicProfiles/alice'), { photoUrl: null }),
    );
  });

  it('refuses an arbitrary photo url on the private profile too', async () => {
    await seedAccount('alice', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/alice'), {
        photoUrl: 'https://attacker.test/b.png',
      }),
    );
  });

  it('refuses an account created with a photo url', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      createAccount(db, 'alice', newUser({ photoUrl: 'https://attacker.test/b.png' })),
    );
  });
});

describe('friendships — who is allowed to ask', () => {
  it('refuses a request from a signed-in principal with no account', async () => {
    // A valid Firebase Auth token with no users/{uid} and no publicProfiles/{uid}
    // — obtainable straight from the Auth REST endpoint without touching the
    // app, and therefore without passing the age gate. Before this rule such a
    // ghost could send requests that counted on the recipient's screen but
    // rendered as nothing, so they could not be declined or reported.
    await seedAccount('bob', 'bob');
    const db = testEnv.authenticatedContext('ghost').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('ghost', 'bob')}`),
        newRequest('ghost', 'bob')),
    );
  });

  it('refuses a request to someone who accepts none', async () => {
    await seedAccount('alice', 'alice');
    await seed('users/bob', newUser({
      username: 'bob',
      privacy: { whoCanSendAura: 'nobody', appearOnLeaderboards: true },
    }));
    await seed('usernames/bob', { uid: 'bob' });
    await seed('publicProfiles/bob', { username: 'bob', photoUrl: null });

    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob')),
    );
  });

  it('still allows a request to someone on the default setting', async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob')),
    );
  });
});

describe('blocks — silent, and effective in both directions', () => {
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  it('lets someone block another user', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/alice/blocks/bob'), {
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('refuses writing into someone else\'s block list', async () => {
    // Would let an attacker make a victim block an arbitrary third party.
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(
      setDoc(doc(db, 'users/alice/blocks/bob'), {
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('refuses reading someone else\'s block list', async () => {
    // This is the whole silence guarantee. If bob could read this, a block
    // would be announced the moment he looked.
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(db, 'users/alice/blocks/bob')));
  });

  it('refuses listing someone else\'s block list', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDocs(collection(db, 'users/alice/blocks')));
  });

  it('lets the owner read their own block list', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(getDocs(collection(db, 'users/alice/blocks')));
  });

  it('refuses blocking yourself', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users/alice/blocks/alice'), {
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('refuses a backdated block', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users/alice/blocks/bob'), { createdAt: new Date(0) }),
    );
  });

  it('refuses extra fields on a block', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, 'users/alice/blocks/bob'), {
        createdAt: serverTimestamp(),
        reason: 'because',
      }),
    );
  });

  it('refuses updating a block', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(db, 'users/alice/blocks/bob'), {
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('lets the owner unblock', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/blocks/bob')));
  });

  it('refuses unblocking on someone else\'s behalf', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(deleteDoc(doc(db, 'users/alice/blocks/bob')));
  });
});

describe('blocks — what they actually stop', () => {
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  it('stops the blocked person requesting the blocker', async () => {
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('bob', 'alice')),
    );
  });

  it('stops the blocker re-requesting the person they blocked', async () => {
    // The second direction. Without it, blocking someone would end only half
    // the relationship — you could still reach them.
    await seedBlock('alice', 'bob');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('alice', 'bob')),
    );
  });

  it('lets requests through again after an unblock', async () => {
    await seedBlock('alice', 'bob');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'users/alice/blocks/bob'));
    });

    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      setDoc(doc(db, `friendships/${pairId('alice', 'bob')}`),
        newRequest('bob', 'alice')),
    );
  });

  it('does not stop unrelated people', async () => {
    await seedAccount('carol', 'carol');
    await seedBlock('alice', 'bob');

    const db = testEnv.authenticatedContext('carol').firestore();
    await assertSucceeds(
      setDoc(doc(db, `friendships/${pairId('carol', 'bob')}`),
        newRequest('carol', 'bob')),
    );
  });
});

describe('reports — filed, never readable', () => {
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  /** A report and its mandatory block, committed together. */
  function fileReport(db, reporter, reported, overrides = {}) {
    const batch = writeBatch(db);
    batch.set(doc(db, 'reports/r1'), {
      reporterUid: reporter,
      reportedUid: reported,
      reason: 'harassment',
      createdAt: serverTimestamp(),
      ...overrides,
    });
    if (!overrides.omitBlock) {
      batch.set(doc(db, `users/${reporter}/blocks/${reported}`), {
        createdAt: serverTimestamp(),
      });
    }
    return batch.commit();
  }

  it('files a report together with its block', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(fileReport(db, 'alice', 'bob'));
  });

  it('refuses a report with no block alongside it', async () => {
    // Nothing reviews this queue, so the block is the only thing that protects
    // the reporter. Coupling them in the rules stops the UI drifting into a
    // report button that quietly does nothing.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      fileReport(db, 'alice', 'bob', { omitBlock: true }),
    );
  });

  it('refuses filing a report as somebody else', async () => {
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(fileReport(db, 'alice', 'bob'));
  });

  it('refuses reporting yourself', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(fileReport(db, 'alice', 'alice'));
  });

  it('refuses an empty or oversized reason', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(fileReport(db, 'alice', 'bob', { reason: '' }));
    await assertFails(
      fileReport(db, 'alice', 'bob', { reason: 'x'.repeat(41) }),
    );
  });

  it('refuses reading a report, even your own', async () => {
    await seed('reports/r1', {
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      createdAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'reports/r1')));
  });

  it('refuses listing reports', async () => {
    await seed('reports/r1', {
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      createdAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDocs(collection(db, 'reports')));
  });

  it('refuses editing or withdrawing a filed report', async () => {
    await seed('reports/r1', {
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      createdAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(updateDoc(doc(db, 'reports/r1'), { reason: 'oops' }));
    await assertFails(deleteDoc(doc(db, 'reports/r1')));
  });
});

describe('account deletion — everything personal goes, the handle does not', () => {
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  /** Deletes both halves of an account in one commit, as the app does. */
  function deleteAccount(db, uid, { omitPublic = false, omitUser = false } = {}) {
    const batch = writeBatch(db);
    if (!omitUser) batch.delete(doc(db, `users/${uid}`));
    if (!omitPublic) batch.delete(doc(db, `publicProfiles/${uid}`));
    return batch.commit();
  }

  it('deletes your own account', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(deleteAccount(db, 'alice'));
  });

  it('refuses deleting the private profile on its own', async () => {
    // Would leave a searchable public handle belonging to nobody.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteAccount(db, 'alice', { omitPublic: true }));
  });

  it('refuses deleting the public profile on its own', async () => {
    // Would leave a real account that no search could ever find.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteAccount(db, 'alice', { omitUser: true }));
  });

  it('refuses deleting somebody else\'s account', async () => {
    const db = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(deleteAccount(db, 'alice'));
  });

  it('refuses releasing the handle, even your own', async () => {
    // The tombstone. Freeing it would let someone squat a churned friend's
    // name and silently re-point every old mention of it.
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(deleteDoc(doc(db, 'usernames/alice')));
  });

  it('refuses releasing the handle as part of the deletion batch', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users/alice'));
    batch.delete(doc(db, 'publicProfiles/alice'));
    batch.delete(doc(db, 'usernames/alice'));
    await assertFails(batch.commit());
  });

  it('lets you delete your friendships as part of leaving', async () => {
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    const batch = writeBatch(db);
    batch.delete(doc(db, `friendships/${pairId('alice', 'bob')}`));
    batch.delete(doc(db, 'users/alice'));
    batch.delete(doc(db, 'publicProfiles/alice'));
    await assertSucceeds(batch.commit());
  });
});

describe('the batch the client actually sends', () => {
  // This suite exists because of a slice 9 security review finding: every other
  // block/report test committed the *pieces* of the client's write, never the
  // write itself. FirestoreSafetyRepository bundles the block document and a
  // friendship delete into one batch, and a batch is atomic — so a denied
  // friendship delete takes the block down with it.
  //
  // The stranger case is the one that matters most: the safety menu is reachable
  // from an invite link sent by someone you have never accepted, which is
  // precisely when there is no friendship document to delete.
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
  });

  /** Byte-for-byte what `FirestoreSafetyRepository._addBlock` writes. */
  function clientBlockBatch(db, viewerUid, blockedUid) {
    const batch = writeBatch(db);
    batch.set(doc(db, `users/${viewerUid}/blocks/${blockedUid}`), {
      createdAt: serverTimestamp(),
    });
    batch.delete(doc(db, `friendships/${pairId(viewerUid, blockedUid)}`));
    return batch.commit();
  }

  it('blocks a stranger you have no friendship with', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(clientBlockBatch(db, 'alice', 'bob'));
  });

  it('blocks someone who sent you a pending request', async () => {
    await seedFriendship('bob', 'alice');
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(clientBlockBatch(db, 'alice', 'bob'));
  });

  it('blocks an accepted friend', async () => {
    await seedFriendship('alice', 'bob', {
      status: 'accepted',
      respondedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(clientBlockBatch(db, 'alice', 'bob'));
  });

  it('reports a stranger, block and report together', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'users/alice/blocks/bob'), {
      createdAt: serverTimestamp(),
    });
    batch.delete(doc(db, `friendships/${pairId('alice', 'bob')}`));
    batch.set(doc(db, 'reports/r1'), {
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });

  it('still refuses deleting a friendship you are not part of', async () => {
    // The fix for the above must not become a friendship-existence oracle. A
    // non-member is denied whether or not the document exists, so the two
    // outcomes are indistinguishable.
    await seedAccount('carol', 'carol');
    const db = testEnv.authenticatedContext('carol').firestore();
    await assertFails(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });

  it('refuses deleting an absent friendship you are not part of', async () => {
    await seedAccount('carol', 'carol');
    const db = testEnv.authenticatedContext('carol').firestore();
    await assertFails(
      deleteDoc(doc(db, `friendships/${pairId('alice', 'bob')}`)),
    );
  });
});

describe('ghost tokens — a signed-in principal with no account', () => {
  // A valid Firebase Auth token is obtainable straight from the REST signup
  // endpoint without ever running the age gate. `friendships` already guards
  // against this; blocks and reports did not, which left an unbounded write
  // path into a shared project-wide daily quota.
  beforeEach(async () => {
    await seedAccount('alice', 'alice');
  });

  it('cannot block', async () => {
    const db = testEnv.authenticatedContext('ghost').firestore();
    await assertFails(
      setDoc(doc(db, 'users/ghost/blocks/alice'), {
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('cannot file a report', async () => {
    const db = testEnv.authenticatedContext('ghost').firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'users/ghost/blocks/alice'), {
      createdAt: serverTimestamp(),
    });
    batch.set(doc(db, 'reports/r1'), {
      reporterUid: 'ghost',
      reportedUid: 'alice',
      reason: 'harassment',
      createdAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });

  it('a real account still can', async () => {
    await seedAccount('bob', 'bob');
    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/bob/blocks/alice'), {
        createdAt: serverTimestamp(),
      }),
    );
  });
});

describe('a block stops an in-flight accept', () => {
  it('refuses accepting a request from someone you have blocked', async () => {
    // Reachable by writing a block document on its own over REST without the
    // friendship delete, and reachable from the app under a race once the two
    // writes are decoupled. Defence in depth: a legitimate accept can never be
    // affected, because a real block severs the document anyway.
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
    await seedFriendship('alice', 'bob');
    await seedBlock('bob', 'alice');

    const db = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });

  it('still allows a normal accept', async () => {
    await seedAccount('alice', 'alice');
    await seedAccount('bob', 'bob');
    await seedFriendship('alice', 'bob');

    const db = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(
      updateDoc(doc(db, `friendships/${pairId('alice', 'bob')}`), {
        status: 'accepted',
        respondedAt: serverTimestamp(),
      }),
    );
  });
});

describe('server-owned aura records', () => {
  it('only participants can read a transaction; clients cannot forge it', async () => {
    await seed('transactions/tx1', { senderId: 'alice', recipientId: 'bob', points: 80 });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'transactions/tx1'), { points: 500 }));
    await assertSucceeds(getDoc(doc(db, 'transactions/tx1')));
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext('bob').firestore(), 'transactions/tx1')));
    await assertFails(getDoc(doc(testEnv.authenticatedContext('carol').firestore(), 'transactions/tx1')));
  });

  it('feeds are owner-readable and cannot be client-written', async () => {
    await seed('users/alice/feed/tx1', { points: 80 });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(setDoc(doc(db, 'users/alice/feed/tx1'), { points: 500 }));
    await assertSucceeds(getDoc(doc(db, 'users/alice/feed/tx1')));
    await assertFails(getDoc(doc(testEnv.authenticatedContext('bob').firestore(), 'users/alice/feed/tx1')));
  });

  it('rate limits are invisible and immutable to every client', async () => {
    await seed('rateLimits/alice_bob', { at: [1] });
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(db, 'rateLimits/alice_bob')));
    await assertFails(setDoc(doc(db, 'rateLimits/alice_bob'), { at: [] }));
  });
});

// A guard on the tests themselves. If `assertFails` were somehow passing for the
// wrong reason (a misconfigured emulator, rules failing to load at all), every
// negative test above would go green while the backend was wide open. This
// asserts the positive direction is real too.
describe('sanity', () => {
  it('the emulator is actually enforcing the rules file', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(createAccount(db, 'alice'));
    await assertFails(createAccount(db, 'bob'));
    assert.ok(true);
  });
});
