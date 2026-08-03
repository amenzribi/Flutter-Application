const assert = require('assert');
const fs = require('fs');
const path = require('path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'barakah-40-rules-test';
const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('Firestore rules — users/{uid}', () => {
  it('denies unauthenticated read', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/alice').set({
        name: 'Alice',
        email: 'alice@example.com',
      });
    });

    const unauth = testEnv.unauthenticatedContext();
    await assertFails(unauth.firestore().doc('users/alice').get());
  });

  it('denies unauthenticated write', async () => {
    const unauth = testEnv.unauthenticatedContext();
    await assertFails(
      unauth.firestore().doc('users/alice').set({
        name: 'Alice',
        email: 'alice@example.com',
      }),
    );
  });

  it('allows user to read own document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/alice').set({
        name: 'Alice',
        email: 'alice@example.com',
      });
    });

    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(alice.firestore().doc('users/alice').get());
  });

  it('allows user to create own document', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice.firestore().doc('users/alice').set({
        name: 'Alice',
        email: 'alice@example.com',
      }),
    );
  });

  it('allows user to update own document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/alice').set({
        name: 'Alice',
        email: 'alice@example.com',
      });
    });

    const alice = testEnv.authenticatedContext('alice');
    await assertSucceeds(
      alice.firestore().doc('users/alice').set(
        { name: 'Alice Updated' },
        { merge: true },
      ),
    );
  });

  it('denies user reading another user document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc('users/bob').set({
        name: 'Bob',
        email: 'bob@example.com',
      });
    });

    const alice = testEnv.authenticatedContext('alice');
    await assertFails(alice.firestore().doc('users/bob').get());
  });

  it('denies user writing another user document', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(
      alice.firestore().doc('users/bob').set({
        name: 'Hacked',
        email: 'bob@example.com',
      }),
    );
  });

  it('denies access to unrelated collections', async () => {
    const alice = testEnv.authenticatedContext('alice');
    await assertFails(
      alice.firestore().doc('directory/alice_key').set({
        uid: 'alice',
      }),
    );
    await assertFails(alice.firestore().doc('stories/s1').get());
    await assertFails(
      alice.firestore().doc('challenges/c1').set({ name: 'x' }),
    );
  });
});

describe('sanity', () => {
  it('loads rules file', () => {
    const rules = fs.readFileSync(RULES_PATH, 'utf8');
    assert.match(rules, /match \/users\/\{userId\}/);
    assert.match(rules, /allow read, write: if isMe\(userId\)/);
  });
});
