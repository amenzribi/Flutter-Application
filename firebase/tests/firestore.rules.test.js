const assert = require('assert');
const fs = require('fs');
const path = require('path');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'barakah-40-rules-test';
const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');
const ts = () => firebase.firestore.FieldValue.serverTimestamp();
const pair = (a, b) => (a < b ? `${a}_${b}` : `${b}_${a}`);

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let testEnv;

const db = (uid, email) =>
  testEnv
    .authenticatedContext(uid, email ? { email } : undefined)
    .firestore();

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await fn(context.firestore());
  });
}

async function seedProfiles(...uids) {
  await seed(async (f) => {
    for (const uid of uids) {
      await f.doc(`profiles/${uid}`).set({
        uid,
        name: uid,
        nameLower: uid,
        username: uid,
      });
    }
  });
}

function requestData(from, to, extra = {}) {
  return {
    from,
    to,
    fromName: from,
    toName: to,
    status: 'pending',
    createdAt: ts(),
    updatedAt: ts(),
    ...extra,
  };
}

async function makeFriends(a, b) {
  const [x, y] = [a, b].sort();
  await seed(async (f) => {
    await f.doc(`friendships/${x}_${y}`).set({
      users: [x, y],
      names: { [x]: x, [y]: y },
      since: Date.now(),
    });
  });
}

function acceptBatch(firestore, from, to) {
  const [x, y] = [from, to].sort();
  const batch = firestore.batch();
  batch.update(firestore.doc(`friendRequests/${from}_${to}`), {
    status: 'accepted',
    updatedAt: ts(),
  });
  batch.set(firestore.doc(`friendships/${x}_${y}`), {
    users: [x, y],
    names: { [x]: x, [y]: y },
    since: ts(),
  });
  return batch.commit();
}

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
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('users/{uid}', () => {
  it('denies unauthenticated read and write', async () => {
    await seed((f) => f.doc('users/alice').set({ name: 'Alice' }));
    const unauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauth.doc('users/alice').get());
    await assertFails(unauth.doc('users/alice').set({ name: 'x' }));
  });

  it('allows owner read/write and denies others', async () => {
    await assertSucceeds(db('alice').doc('users/alice').set({ name: 'A' }));
    await assertSucceeds(db('alice').doc('users/alice').get());
    await assertFails(db('bob').doc('users/alice').get());
    await assertFails(db('bob').doc('users/alice').set({ name: 'Hacked' }));
  });

  it('denies unrelated collections', async () => {
    await assertFails(db('alice').doc('directory/x').set({ uid: 'alice' }));
    await assertFails(db('alice').doc('stories/s1').get());
  });
});

describe('profiles and email lookup', () => {
  const profile = (uid) => ({
    uid,
    name: 'Alice Z',
    nameLower: 'alice z',
    username: 'alice.z',
    createdAt: ts(),
    updatedAt: ts(),
  });

  it('owner writes own profile only, with valid fields', async () => {
    await assertSucceeds(db('alice').doc('profiles/alice').set(profile('alice')));
    await assertFails(db('bob').doc('profiles/alice').set(profile('alice')));
    await assertFails(
      db('alice').doc('profiles/alice').set({ ...profile('alice'), email: 'a@x.com' }),
    );
    await assertFails(
      db('alice').doc('profiles/alice').set({ ...profile('alice'), nameLower: 'other' }),
    );
  });

  it('allows small prefix queries but not dumping profiles', async () => {
    await seedProfiles('alice', 'bob');
    const f = db('bob');
    await assertSucceeds(
      f.collection('profiles').where('username', '>=', 'al').where('username', '<', 'al').limit(10).get(),
    );
    await assertFails(f.collection('profiles').get());
    await assertFails(f.collection('profiles').limit(500).get());
  });

  it('emailIndex: only the signed-in email can be claimed', async () => {
    await assertSucceeds(
      db('alice', 'Alice@Example.com').doc('emailIndex/alice@example.com').set({ uid: 'alice' }),
    );
    await assertFails(
      db('mallory', 'm@evil.com').doc('emailIndex/bob@example.com').set({ uid: 'mallory' }),
    );
    await assertFails(
      db('mallory', 'm@evil.com').doc('emailIndex/alice@example.com').set({ uid: 'mallory' }),
    );
  });

  it('emailIndex: exact get allowed, list denied', async () => {
    await seed((f) => f.doc('emailIndex/alice@example.com').set({ uid: 'alice' }));
    await assertSucceeds(db('bob').doc('emailIndex/alice@example.com').get());
    await assertFails(db('bob').collection('emailIndex').limit(5).get());
    await assertFails(testEnv.unauthenticatedContext().firestore().doc('emailIndex/alice@example.com').get());
  });
});

describe('friend requests', () => {
  beforeEach(() => seedProfiles('alice', 'bob', 'carol'));

  it('sender can create a pending request with the right id', async () => {
    await assertSucceeds(db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
  });

  it('rejects self-invitation, spoofed sender, wrong id, unknown user', async () => {
    await assertFails(db('alice').doc('friendRequests/alice_alice').set(requestData('alice', 'alice')));
    await assertFails(db('carol').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
    await assertFails(db('alice').doc('friendRequests/x').set(requestData('alice', 'bob')));
    await assertFails(db('alice').doc('friendRequests/alice_ghost').set(requestData('alice', 'ghost')));
    await assertFails(
      db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob', { status: 'accepted' })),
    );
  });

  it('prevents a duplicate pending request (second create is an update)', async () => {
    await assertSucceeds(db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
    await assertFails(db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
  });

  it('prevents a request when the reverse one is pending', async () => {
    await assertSucceeds(db('bob').doc('friendRequests/bob_alice').set(requestData('bob', 'alice')));
    await assertFails(db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
  });

  it('prevents a request to an existing friend', async () => {
    await makeFriends('alice', 'bob');
    await assertFails(db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob')));
  });

  it('only the two parties can read a request', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertSucceeds(db('alice').doc('friendRequests/alice_bob').get());
    await assertSucceeds(db('bob').doc('friendRequests/alice_bob').get());
    await assertFails(db('carol').doc('friendRequests/alice_bob').get());
    await assertSucceeds(
      db('bob').collection('friendRequests').where('to', '==', 'bob').where('status', '==', 'pending').get(),
    );
    await assertFails(db('carol').collection('friendRequests').where('status', '==', 'pending').get());
  });

  it('recipient declines, sender cancels, and nobody else can', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    const cancel = { status: 'cancelled', updatedAt: ts() };
    const decline = { status: 'declined', updatedAt: ts() };
    await assertFails(db('carol').doc('friendRequests/alice_bob').update(decline));
    await assertFails(db('bob').doc('friendRequests/alice_bob').update(cancel));
    await assertFails(db('alice').doc('friendRequests/alice_bob').update(decline));
    await assertSucceeds(db('bob').doc('friendRequests/alice_bob').update(decline));
    // Declined can be re-sent by the sender, then cancelled.
    await assertSucceeds(db('alice').doc('friendRequests/alice_bob').update({ status: 'pending', updatedAt: ts() }));
    await assertSucceeds(db('alice').doc('friendRequests/alice_bob').update(cancel));
  });

  it('sender cannot accept their own request or rewrite parties', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertFails(acceptBatch(db('alice'), 'alice', 'bob'));
    await assertFails(db('alice').doc('friendRequests/alice_bob').update({ to: 'carol', updatedAt: ts() }));
  });

  it('accept creates the friendship atomically', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertSucceeds(acceptBatch(db('bob'), 'alice', 'bob'));
    await assertSucceeds(db('alice').doc(`friendships/${pair('alice', 'bob')}`).get());
    await assertSucceeds(db('bob').doc(`friendships/${pair('alice', 'bob')}`).get());
    await assertFails(db('carol').doc(`friendships/${pair('alice', 'bob')}`).get());
  });

  it('accepting without the friendship write is denied', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertFails(db('bob').doc('friendRequests/alice_bob').update({ status: 'accepted', updatedAt: ts() }));
  });

  it('friendship cannot be forged without a pending request', async () => {
    const [x, y] = ['alice', 'carol'].sort();
    await assertFails(
      db('alice').doc(`friendships/${x}_${y}`).set({ users: [x, y], names: {}, since: ts() }),
    );
  });

  it('a second accept of a crossed request is allowed once friends', async () => {
    // Both sent at the same moment (seeded to bypass the reverse check).
    await seed(async (f) => {
      await f.doc('friendRequests/alice_bob').set({ ...requestData('alice', 'bob'), createdAt: 1, updatedAt: 1 });
      await f.doc('friendRequests/bob_alice').set({ ...requestData('bob', 'alice'), createdAt: 1, updatedAt: 1 });
    });
    await assertSucceeds(acceptBatch(db('bob'), 'alice', 'bob'));
    // Alice closes the other one: friendship already exists, plain update.
    await assertSucceeds(db('alice').doc('friendRequests/bob_alice').update({ status: 'accepted', updatedAt: ts() }));
  });

  it('either friend can unfriend; outsiders cannot', async () => {
    await makeFriends('alice', 'bob');
    await assertFails(db('carol').doc(`friendships/${pair('alice', 'bob')}`).delete());
    await assertSucceeds(db('bob').doc(`friendships/${pair('alice', 'bob')}`).delete());
  });

  it('requests cannot be deleted', async () => {
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertFails(db('alice').doc('friendRequests/alice_bob').delete());
  });
});

describe('direct conversations', () => {
  const cid = pair('alice', 'bob');
  const conv = () => {
    const [x, y] = ['alice', 'bob'].sort();
    return {
      type: 'direct',
      members: [x, y],
      names: { [x]: x, [y]: y },
      createdAt: ts(),
      updatedAt: ts(),
      lastMessage: null,
      unread: { [x]: 0, [y]: 0 },
    };
  };
  const msg = (sender, text = 'السلام عليكم') => ({
    senderId: sender,
    senderName: sender,
    text,
    createdAt: ts(),
  });

  beforeEach(() => seedProfiles('alice', 'bob', 'carol'));

  it('friends can open a conversation; strangers cannot', async () => {
    await assertFails(db('alice').doc(`conversations/${cid}`).set(conv()));
    await makeFriends('alice', 'bob');
    await assertFails(db('carol').doc(`conversations/${cid}`).set(conv()));
    await assertSucceeds(db('alice').doc(`conversations/${cid}`).set(conv()));
  });

  it('conversation id must be the pair id', async () => {
    await makeFriends('alice', 'bob');
    await assertFails(db('alice').doc('conversations/random').set(conv()));
  });

  it('members send and read; outsiders cannot even with the id', async () => {
    await makeFriends('alice', 'bob');
    await db('alice').doc(`conversations/${cid}`).set(conv());
    await assertSucceeds(db('alice').collection(`conversations/${cid}/messages`).add(msg('alice')));
    await assertSucceeds(db('bob').collection(`conversations/${cid}/messages`).orderBy('createdAt').limit(50).get());
    await assertFails(db('carol').collection(`conversations/${cid}/messages`).get());
    await assertFails(db('carol').doc(`conversations/${cid}`).get());
    await assertFails(db('carol').collection(`conversations/${cid}/messages`).add(msg('carol')));
  });

  it('rejects spoofed sender, empty or oversized text, client timestamps', async () => {
    await makeFriends('alice', 'bob');
    await db('alice').doc(`conversations/${cid}`).set(conv());
    const col = db('alice').collection(`conversations/${cid}/messages`);
    await assertFails(col.add(msg('bob')));
    await assertFails(col.add(msg('alice', '   ')));
    await assertFails(col.add(msg('alice', 'x'.repeat(2001))));
    await assertFails(col.add({ ...msg('alice'), createdAt: 12345 }));
  });

  it('messages are immutable', async () => {
    await makeFriends('alice', 'bob');
    await db('alice').doc(`conversations/${cid}`).set(conv());
    const ref = await db('alice').collection(`conversations/${cid}/messages`).add(msg('alice'));
    await assertFails(db('alice').doc(ref.path).update({ text: 'edited' }));
    await assertFails(db('bob').doc(ref.path).delete());
  });

  it('sending is blocked after unfriending', async () => {
    await makeFriends('alice', 'bob');
    await db('alice').doc(`conversations/${cid}`).set(conv());
    await db('bob').doc(`friendships/${cid}`).delete();
    await assertFails(db('alice').collection(`conversations/${cid}/messages`).add(msg('alice')));
  });

  it('members update preview/unread but cannot change membership', async () => {
    await makeFriends('alice', 'bob');
    await db('alice').doc(`conversations/${cid}`).set(conv());
    await assertSucceeds(
      db('bob').doc(`conversations/${cid}`).update({ 'unread.bob': 0, updatedAt: ts() }),
    );
    await assertFails(db('bob').doc(`conversations/${cid}`).update({ members: ['bob', 'carol'] }));
  });
});

describe('challenges and group discussion', () => {
  const chal = (owner, members, type = 'group') => ({
    type,
    name: 'تحدّي البقرة',
    ownerUid: owner,
    members,
    names: {},
    createdAt: ts(),
    updatedAt: ts(),
    goalDays: 40,
    lastMessage: null,
  });
  const msg = (sender) => ({ senderId: sender, senderName: sender, text: 'هيا بنا', createdAt: ts() });

  beforeEach(async () => {
    await seedProfiles('alice', 'bob', 'carol', 'dave');
    await makeFriends('alice', 'bob');
    await makeFriends('bob', 'carol');
  });

  async function group() {
    const ref = db('alice').collection('challenges').doc('g1');
    await ref.set(chal('alice', ['alice']));
    return ref;
  }

  it('creates with self only, or with one friend for duo', async () => {
    await assertSucceeds(db('alice').doc('challenges/c1').set(chal('alice', ['alice'])));
    await assertSucceeds(db('alice').doc('challenges/c2').set(chal('alice', ['alice', 'bob'], 'duo')));
    await assertFails(db('alice').doc('challenges/c3').set(chal('alice', ['alice', 'carol'], 'duo')));
    await assertFails(db('alice').doc('challenges/c4').set(chal('bob', ['alice'])));
  });

  it('member adds one of their friends; non-friends and outsiders denied', async () => {
    await group();
    const add = (f, uid) =>
      f.doc('challenges/g1').update({
        members: firebase.firestore.FieldValue.arrayUnion(uid),
        updatedAt: ts(),
      });
    await assertFails(add(db('alice'), 'carol')); // not Alice's friend
    await assertFails(add(db('bob'), 'carol')); // Bob is not a member yet
    await assertSucceeds(add(db('alice'), 'bob'));
    await assertSucceeds(add(db('bob'), 'carol')); // Bob's friend
    await assertFails(add(db('dave'), 'dave'));
  });

  it('only members read the group and its messages', async () => {
    await group();
    await assertSucceeds(db('alice').doc('challenges/g1').get());
    await assertFails(db('dave').doc('challenges/g1').get());
    await assertSucceeds(db('alice').collection('challenges/g1/messages').add(msg('alice')));
    await assertFails(db('dave').collection('challenges/g1/messages').get());
    await assertFails(db('dave').collection('challenges/g1/messages').add(msg('dave')));
    await assertSucceeds(
      db('alice').collection('challenges').where('members', 'array-contains', 'alice').get(),
    );
  });

  it('member leaves, loses access; owner removes members', async () => {
    const ref = await group();
    await ref.update({ members: firebase.firestore.FieldValue.arrayUnion('bob'), updatedAt: ts() });
    await db('bob').doc('challenges/g1').update({ members: firebase.firestore.FieldValue.arrayUnion('carol'), updatedAt: ts() });
    await assertSucceeds(
      db('carol').doc('challenges/g1').update({ members: firebase.firestore.FieldValue.arrayRemove('carol'), updatedAt: ts() }),
    );
    await assertFails(db('carol').collection('challenges/g1/messages').get());
    // Bob cannot remove the owner; owner removes Bob.
    await assertFails(
      db('bob').doc('challenges/g1').update({ members: firebase.firestore.FieldValue.arrayRemove('alice'), updatedAt: ts() }),
    );
    await assertSucceeds(
      db('alice').doc('challenges/g1').update({ members: firebase.firestore.FieldValue.arrayRemove('bob'), updatedAt: ts() }),
    );
  });

  it('only the owner renames or deletes', async () => {
    const ref = await group();
    await ref.update({ members: firebase.firestore.FieldValue.arrayUnion('bob'), updatedAt: ts() });
    await assertFails(db('bob').doc('challenges/g1').update({ name: 'x', updatedAt: ts() }));
    await assertFails(db('bob').doc('challenges/g1').update({ ownerUid: 'bob' }));
    await assertSucceeds(db('alice').doc('challenges/g1').update({ name: 'جديد', updatedAt: ts() }));
    await assertFails(db('bob').doc('challenges/g1').delete());
    await assertSucceeds(db('alice').doc('challenges/g1').delete());
  });

  it('progress: each member writes own row only', async () => {
    const ref = await group();
    await ref.update({ members: firebase.firestore.FieldValue.arrayUnion('bob'), updatedAt: ts() });
    await assertSucceeds(db('bob').doc('challenges/g1/progress/bob').set({ uid: 'bob', days: 3 }));
    await assertFails(db('bob').doc('challenges/g1/progress/alice').set({ uid: 'alice', days: 40 }));
    await assertSucceeds(db('alice').doc('challenges/g1/progress/bob').get());
    await assertFails(db('dave').doc('challenges/g1/progress/bob').get());
  });
});

describe('existence checks', () => {
  it('a missing request/friendship/conversation can be probed, existing ones stay private', async () => {
    await seedProfiles('alice', 'bob', 'carol');
    await assertSucceeds(db('carol').doc('friendRequests/alice_bob').get());
    await assertSucceeds(db('carol').doc(`friendships/${pair('alice', 'bob')}`).get());
    await assertSucceeds(db('carol').doc(`conversations/${pair('alice', 'bob')}`).get());
    await db('alice').doc('friendRequests/alice_bob').set(requestData('alice', 'bob'));
    await assertFails(db('carol').doc('friendRequests/alice_bob').get());
  });
});
