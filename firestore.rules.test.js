/**
 * Firestore security rules unit tests — notifications collection
 *
 * Run with:
 *   npm install
 *   npm test
 *
 * Requires the Firebase Emulator Suite:
 *   firebase emulators:start --only firestore
 */

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'minaret-test';
const RULES_PATH = path.join(__dirname, 'firestore.rules');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ── helpers ───────────────────────────────────────────────────────────────────

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

function notifDoc(db, notificationId) {
  return db.collection('notifications').doc(notificationId);
}

// ── notifications — create ────────────────────────────────────────────────────

describe('notifications — create', () => {
  test('✅ authenticated user can create a notification for themselves', async () => {
    const uid = 'user-alice';
    const db = authedDb(uid);
    await assertSucceeds(
      notifDoc(db, 'notif-1').set({
        userId: uid,
        title: 'Prayer time',
        read: false,
        createdAt: new Date(),
      }),
    );
  });

  test('❌ authenticated user cannot create a notification for another user', async () => {
    // User "eve" tries to create a notification with userId = "bob".
    // This was the bug: the old rule used isAuthenticated() which allowed this.
    const db = authedDb('user-eve');
    await assertFails(
      notifDoc(db, 'notif-2').set({
        userId: 'user-bob',  // different uid — must be rejected
        title: 'Hacked notification',
        read: false,
        createdAt: new Date(),
      }),
    );
  });

  test('❌ unauthenticated user cannot create any notification', async () => {
    const db = unauthDb();
    await assertFails(
      notifDoc(db, 'notif-3').set({
        userId: 'user-alice',
        title: 'Unauthenticated write',
        read: false,
        createdAt: new Date(),
      }),
    );
  });
});

// ── notifications — read ──────────────────────────────────────────────────────

describe('notifications — read', () => {
  test('✅ owner can read their own notification', async () => {
    const uid = 'user-alice';
    // Seed via admin context to bypass write rules
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notifications').doc('notif-r1').set({
        userId: uid,
        title: 'Test',
        read: false,
      });
    });

    const db = authedDb(uid);
    await assertSucceeds(notifDoc(db, 'notif-r1').get());
  });

  test('❌ another user cannot read someone else\'s notification', async () => {
    const ownerUid = 'user-alice';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notifications').doc('notif-r2').set({
        userId: ownerUid,
        title: 'Private',
        read: false,
      });
    });

    const db = authedDb('user-eve');
    await assertFails(notifDoc(db, 'notif-r2').get());
  });
});

// ── notifications — update ────────────────────────────────────────────────────

describe('notifications — update', () => {
  test('✅ owner can mark notification as read', async () => {
    const uid = 'user-alice';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notifications').doc('notif-u1').set({
        userId: uid,
        title: 'Test',
        read: false,
      });
    });

    const db = authedDb(uid);
    await assertSucceeds(notifDoc(db, 'notif-u1').update({ read: true }));
  });

  test('❌ owner cannot change userId on existing notification', async () => {
    const uid = 'user-alice';
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('notifications').doc('notif-u2').set({
        userId: uid,
        title: 'Test',
        read: false,
      });
    });

    const db = authedDb(uid);
    await assertFails(
      notifDoc(db, 'notif-u2').update({ userId: 'user-bob' }),
    );
  });
});
