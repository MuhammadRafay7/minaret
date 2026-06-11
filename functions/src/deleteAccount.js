// functions/src/deleteAccount.js
//
// Firebase Cloud Function: deleteAccount
//
// Handles full account deletion server-side per GDPR/PDPA/Apple requirements.
// Soft-deletes and anonymises the Firestore user document, removes mosque follows,
// deletes prayer data and preferences, then deletes the Firebase Auth account.
// Audit records (reports, janaza) are NOT deleted — only anonymised.
//
// Deploy: firebase deploy --only functions:deleteAccount

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.deleteAccount = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    // ── Step 1: Soft-delete and anonymise users/{uid} ─────────────────────
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      await userRef.set(
        {
          accountStatus: "deleted",
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          displayName: "[Deleted User]",
          email: `deleted_${uid}@deleted.invalid`,
          fcmToken: admin.firestore.FieldValue.delete(),
          photoUrl: admin.firestore.FieldValue.delete(),
          phoneNumber: admin.firestore.FieldValue.delete(),
        },
        { merge: true },
      );
    }

    // ── Step 2: Remove mosque follows and decrement followerCount ─────────
    const followsSnap = await db
      .collection("mosque_followers")
      .where("userId", "==", uid)
      .get();

    const mosqueIds = new Set();
    followsSnap.forEach((doc) => {
      mosqueIds.add(doc.data().mosqueId);
    });

    // Batch: delete follow docs + decrement counts
    // Firestore batch limit is 500; typical user follows far fewer mosques.
    const batch = db.batch();

    followsSnap.forEach((doc) => {
      batch.delete(doc.ref);
    });

    for (const mosqueId of mosqueIds) {
      const mosqueRef = db.collection("mosques").doc(mosqueId);
      batch.update(mosqueRef, {
        followerCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    // ── Step 3: Delete prayer stats, tracking, and preferences ───────────
    batch.delete(db.collection("user_prayer_stats").doc(uid));
    batch.delete(db.collection("prayer_tracking").doc(uid));
    batch.delete(db.collection("user_preferences").doc(uid));

    await batch.commit();

    // ── Step 4: Anonymise reports authored by this user ───────────────────
    // Reports are kept for moderation audit — only the userId is cleared.
    const reportsSnap = await db
      .collection("reports")
      .where("userId", "==", uid)
      .get();

    if (!reportsSnap.empty) {
      const reportBatch = db.batch();
      reportsSnap.forEach((doc) => {
        reportBatch.update(doc.ref, {
          userId: "[deleted]",
          reporterDisplayName: "[Deleted User]",
        });
      });
      await reportBatch.commit();
    }

    // ── Step 5: Delete Firebase Auth account ─────────────────────────────
    await admin.auth().deleteUser(uid);

    return { success: true };
  },
);
