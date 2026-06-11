// functions/src/deleteMosque.js
//
// Firebase Cloud Function: deleteMosque (onCall)
//
// Cascades deletion of a mosque and all orphaned data:
//   1. Deletes subcollections: announcements, prayerTimes, notifications, events
//   2. Removes mosqueId from all users' followedMosques arrays
//   3. Deletes mosque_followers documents
//   4. Soft-deletes janaza_announcements (active: false — kept for audit)
//   5. Writes an audit_log entry
//   6. Deletes the mosque document itself
//
// Callable from the Flutter app or directly from the admin panel client.
// The admin panel API route (/api/mosques/[id] DELETE) implements the same
// steps server-side via Admin SDK to avoid cross-server HTTP overhead.
//
// Deploy: firebase deploy --only functions:deleteMosque

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const ALLOWED_ROLES = ["super_admin", "admin", "mosque_admin"];
const SUBCOLLECTIONS = ["announcements", "prayerTimes", "notifications", "events"];

async function deleteSubcollections(mosqueRef) {
  for (const sub of SUBCOLLECTIONS) {
    const snap = await mosqueRef.collection(sub).limit(500).get();
    if (!snap.empty) {
      const batch = admin.firestore().batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  }
}

async function removeFollowers(db, mosqueId) {
  const followersSnap = await db
    .collection("mosque_followers")
    .where("mosqueId", "==", mosqueId)
    .get();

  if (followersSnap.empty) return;

  const userIds = followersSnap.docs
    .map((d) => d.data().userId)
    .filter(Boolean);

  const CHUNK = 500;
  for (let i = 0; i < userIds.length; i += CHUNK) {
    const batch = db.batch();
    userIds.slice(i, i + CHUNK).forEach((uid) => {
      batch.update(db.collection("users").doc(uid), {
        followedMosques: admin.firestore.FieldValue.arrayRemove(mosqueId),
      });
    });
    await batch.commit();
  }

  // Delete the follower documents in chunks
  for (let i = 0; i < followersSnap.docs.length; i += CHUNK) {
    const batch = db.batch();
    followersSnap.docs.slice(i, i + CHUNK).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

async function softDeleteJanaza(db, mosqueId) {
  const janazaSnap = await db
    .collection("janaza_announcements")
    .where("mosqueId", "==", mosqueId)
    .get();

  if (!janazaSnap.empty) {
    const batch = db.batch();
    janazaSnap.docs.forEach((d) =>
      batch.update(d.ref, {
        active: false,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    );
    await batch.commit();
  }
}

exports.deleteMosque = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const db = admin.firestore();

    // Verify caller has an admin role
    const callerDoc = await db
      .collection("users")
      .doc(request.auth.uid)
      .get();

    const callerRole = callerDoc.data()?.role;
    if (!ALLOWED_ROLES.includes(callerRole)) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { mosqueId } = request.data ?? {};
    if (!mosqueId || typeof mosqueId !== "string") {
      throw new HttpsError("invalid-argument", "mosqueId is required.");
    }

    const mosqueRef = db.collection("mosques").doc(mosqueId);
    const mosqueDoc = await mosqueRef.get();
    if (!mosqueDoc.exists) {
      throw new HttpsError("not-found", "Mosque not found.");
    }

    const mosqueData = mosqueDoc.data();

    await deleteSubcollections(mosqueRef);
    await removeFollowers(db, mosqueId);
    await softDeleteJanaza(db, mosqueId);

    await db.collection("audit_logs").add({
      action: "mosque_deleted",
      mosqueId,
      mosqueName: mosqueData.name ?? "Unknown",
      followerCount: mosqueData.followerCount ?? 0,
      performedBy: request.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await mosqueRef.delete();

    return { success: true };
  },
);
