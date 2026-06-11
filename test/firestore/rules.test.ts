/**
 * Firestore security rules tests for Minaret.
 *
 * Prerequisites:
 *   1. Install deps: npm ci (from this directory)
 *   2. Firebase emulator must be running on port 8080.
 *      Run standalone: firebase emulators:start --only firestore --project minaret-f3793
 *      Or via CI: firebase emulators:exec --only firestore -- npx vitest run
 *
 * The rules file is read from: ../../firestore.rules
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, collection,
  serverTimestamp,
} from 'firebase/firestore';

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

const PROJECT_ID = 'minaret-f3793';
const RULES_PATH = resolve(__dirname, '../../firestore.rules');

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function authed(uid: string) {
  return testEnv.authenticatedContext(uid);
}

function unauthed() {
  return testEnv.unauthenticatedContext();
}

async function seedUser(uid: string, data: Record<string, unknown>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), data);
  });
}

async function seedMosque(mosqueId: string, data: Record<string, unknown>) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'mosques', mosqueId), data);
  });
}

// ---------------------------------------------------------------------------
// users/{userId}
// ---------------------------------------------------------------------------

describe('users/{userId}', () => {
  it('owner can read their own document', async () => {
    await seedUser('uid-a', { role: 'user', displayName: 'Alice' });
    const db = authed('uid-a').firestore();
    await assertSucceeds(getDoc(doc(db, 'users', 'uid-a')));
  });

  it('other authenticated user cannot read a different user', async () => {
    await seedUser('uid-a', { role: 'user' });
    const db = authed('uid-b').firestore();
    await assertFails(getDoc(doc(db, 'users', 'uid-a')));
  });

  it('unauthenticated user cannot read any user', async () => {
    await seedUser('uid-a', { role: 'user' });
    const db = unauthed().firestore();
    await assertFails(getDoc(doc(db, 'users', 'uid-a')));
  });

  it('owner can update their own document (non-privileged fields)', async () => {
    await seedUser('uid-a', { role: 'user', displayName: 'Alice' });
    const db = authed('uid-a').firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', 'uid-a'), { displayName: 'Alice B.' }));
  });

  it('owner cannot self-elevate role', async () => {
    await seedUser('uid-a', { role: 'user' });
    const db = authed('uid-a').firestore();
    await assertFails(updateDoc(doc(db, 'users', 'uid-a'), { role: 'super_admin' }));
  });

  it('owner cannot self-assign superAdminPermissions', async () => {
    await seedUser('uid-a', { role: 'user' });
    const db = authed('uid-a').firestore();
    await assertFails(updateDoc(doc(db, 'users', 'uid-a'), {
      superAdminPermissions: { assignedMosqueIds: ['mosque-1'] },
    }));
  });

  it('owner cannot self-set mfaEnrolled', async () => {
    await seedUser('uid-a', { role: 'user' });
    const db = authed('uid-a').firestore();
    await assertFails(updateDoc(doc(db, 'users', 'uid-a'), { mfaEnrolled: true }));
  });

  it('owner cannot self-set accountStatus', async () => {
    await seedUser('uid-a', { role: 'user', accountStatus: 'active' });
    const db = authed('uid-a').firestore();
    await assertFails(updateDoc(doc(db, 'users', 'uid-a'), { accountStatus: 'active' }));
  });

  it('authenticated user can create their own document', async () => {
    const db = authed('uid-new').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users', 'uid-new'), { role: 'user', email: 'new@test.com' }),
    );
  });

  it('user cannot create a document for another uid', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'uid-b'), { role: 'user' }),
    );
  });
});

// ---------------------------------------------------------------------------
// mosques/{mosqueId}
// ---------------------------------------------------------------------------

describe('mosques/{mosqueId}', () => {
  it('unauthenticated user can read a mosque', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-admin' });
    const db = unauthed().firestore();
    await assertSucceeds(getDoc(doc(db, 'mosques', 'mosque-1')));
  });

  it('mosque owner can update non-verification fields', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-admin', isVerified: false });
    const db = authed('uid-admin').firestore();
    await assertSucceeds(updateDoc(doc(db, 'mosques', 'mosque-1'), { name: 'Updated Mosque' }));
  });

  it('mosque owner cannot self-verify their mosque', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-admin', isVerified: false });
    const db = authed('uid-admin').firestore();
    await assertFails(updateDoc(doc(db, 'mosques', 'mosque-1'), { isVerified: true, verifiedAt: serverTimestamp() }));
  });

  it('non-owner cannot update mosque', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-admin' });
    const db = authed('uid-other').firestore();
    await assertFails(updateDoc(doc(db, 'mosques', 'mosque-1'), { name: 'Hacked' }));
  });

  it('mosque owner can delete their own mosque', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-owner' });
    const db = authed('uid-owner').firestore();
    await assertSucceeds(deleteDoc(doc(db, 'mosques', 'mosque-1')));
  });

  it('non-owner cannot delete a mosque', async () => {
    await seedMosque('mosque-1', { name: 'Grand Mosque', adminUid: 'uid-owner' });
    const db = authed('uid-other').firestore();
    await assertFails(deleteDoc(doc(db, 'mosques', 'mosque-1')));
  });
});

// ---------------------------------------------------------------------------
// audit_logs/{logId} — insert-only
// ---------------------------------------------------------------------------

describe('audit_logs/{logId} (insert-only, server-side writes only)', () => {
  it('authenticated user cannot create an audit log', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(
      setDoc(doc(db, 'audit_logs', 'log-1'), { action: 'fake_action', uid: 'uid-a' }),
    );
  });

  it('unauthenticated client cannot create an audit log', async () => {
    const db = unauthed().firestore();
    await assertFails(
      setDoc(doc(db, 'audit_logs', 'log-1'), { action: 'fake_action' }),
    );
  });

  it('no user can update an audit log', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'audit_logs', 'log-1'), { action: 'ban', uid: 'uid-a' });
    });
    const db = authed('uid-super').firestore();
    await assertFails(updateDoc(doc(db, 'audit_logs', 'log-1'), { action: 'tampered' }));
  });

  it('super_admin cannot delete an audit log', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'audit_logs', 'log-1'), { action: 'ban' });
      // Seed super_admin user so the isAdmin() function resolves
      await setDoc(doc(ctx.firestore(), 'users', 'uid-super'), { role: 'super_admin' });
    });
    const db = authed('uid-super').firestore();
    await assertFails(deleteDoc(doc(db, 'audit_logs', 'log-1')));
  });
});

// ---------------------------------------------------------------------------
// _nur_rate_limits — no client access
// ---------------------------------------------------------------------------

describe('_nur_rate_limits (Cloud Function only)', () => {
  it('authenticated user cannot read rate limit counters', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(getDoc(doc(db, '_nur_rate_limits', 'uid-a')));
  });

  it('authenticated user cannot write rate limit counters', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(setDoc(doc(db, '_nur_rate_limits', 'uid-a'), { count: 0 }));
  });
});

// ---------------------------------------------------------------------------
// phone_verifications — no client access
// ---------------------------------------------------------------------------

describe('phone_verifications (server-only)', () => {
  it('cannot be read by any client', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(getDoc(doc(db, 'phone_verifications', '+15555555555')));
  });

  it('cannot be written by any client', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(setDoc(doc(db, 'phone_verifications', '+15555555555'), { verified: true }));
  });
});

// ---------------------------------------------------------------------------
// Catch-all — everything else denied
// ---------------------------------------------------------------------------

describe('catch-all deny', () => {
  it('unknown collection is denied for authenticated users', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(setDoc(doc(db, 'unknown_collection', 'doc-1'), { data: true }));
  });

  it('unknown collection is denied for unauthenticated users', async () => {
    const db = unauthed().firestore();
    await assertFails(getDoc(doc(db, 'unknown_collection', 'doc-1')));
  });
});

// ---------------------------------------------------------------------------
// notifications/{notificationId} — owner scoped
// ---------------------------------------------------------------------------

describe('notifications/{notificationId}', () => {
  it('owner can create their own notification', async () => {
    const db = authed('uid-a').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'notifications', 'notif-1'), { userId: 'uid-a', message: 'test', read: false }),
    );
  });

  it('user cannot create a notification for another user', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(
      setDoc(doc(db, 'notifications', 'notif-1'), { userId: 'uid-b', message: 'test', read: false }),
    );
  });

  it('owner can mark their notification as read', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'notifications', 'notif-1'), {
        userId: 'uid-a', message: 'test', read: false,
      });
    });
    const db = authed('uid-a').firestore();
    await assertSucceeds(updateDoc(doc(db, 'notifications', 'notif-1'), { read: true }));
  });

  it('owner cannot update notification fields other than read', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'notifications', 'notif-1'), {
        userId: 'uid-a', message: 'test', read: false,
      });
    });
    const db = authed('uid-a').firestore();
    await assertFails(updateDoc(doc(db, 'notifications', 'notif-1'), { message: 'tampered' }));
  });
});

// ---------------------------------------------------------------------------
// prayer_records/{recordId} — uid-prefixed
// ---------------------------------------------------------------------------

describe('prayer_records/{recordId}', () => {
  it('owner can create a prayer record with their uid prefix', async () => {
    const db = authed('uid-a').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'prayer_records', 'uid-a_2024-01-01'), {
        userId: 'uid-a', date: '2024-01-01', prayers: {},
      }),
    );
  });

  it('user cannot create a prayer record for another user', async () => {
    const db = authed('uid-a').firestore();
    await assertFails(
      setDoc(doc(db, 'prayer_records', 'uid-b_2024-01-01'), {
        userId: 'uid-b', date: '2024-01-01',
      }),
    );
  });

  it('owner can delete their own prayer record', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'prayer_records', 'uid-a_2024-01-01'), {
        userId: 'uid-a',
      });
    });
    const db = authed('uid-a').firestore();
    await assertSucceeds(deleteDoc(doc(db, 'prayer_records', 'uid-a_2024-01-01')));
  });
});
