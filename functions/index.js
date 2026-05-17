/**
 * Firebase Cloud Functions for Minaret
 *
 * Includes:
 * 1. janazaNotification: Sends push notifications for new janaza announcements.
 * 2. processNotificationQueue: Processes the admin broadcast queue.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Trigger: janaza_announcements/{announcementId} onCreate
 * Purpose: Notifies followers and hometown residents of a new Janaza.
 */
exports.janazaNotification = functions.firestore
  .document("janaza_announcements/{announcementId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Only send for active announcements
    if (!data.active) return null;

    const mosqueId = data.mosqueId;
    const mosqueName = data.mosqueName || "A mosque";
    const deceasedName = data.deceasedName || "Unknown";
    const city = data.city || "";
    const janazaTime = data.janazaTime?.toDate();
    const timeStr = janazaTime
      ? janazaTime.toLocaleTimeString("en-US", {
          hour: "2-digit",
          minute: "2-digit",
        })
      : "";

    const title = `إِنَّا لِلَّهِ — Janaza Announcement`;
    const body = timeStr
      ? `${deceasedName} · Namaz-e-Janaza at ${timeStr} · ${mosqueName}`
      : `${deceasedName} · Namaz-e-Janaza · ${mosqueName}`;

    const tokens = new Set();

    // 1. Users who follow this mosque
    const followersSnap = await db
      .collection("users")
      .where("followedMosques", "array-contains", mosqueId)
      .get();

    followersSnap.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token) tokens.add(token);
    });

    // 2. Users whose hometown matches this city
    if (city) {
      const citySnap = await db
        .collection("users")
        .where("homeTown", "==", city)
        .get();

      citySnap.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) tokens.add(token);
      });
    }

    if (tokens.size === 0) return null;

    const tokenArray = Array.from(tokens);
    const batchSize = 500;
    const batches = [];

    for (let i = 0; i < tokenArray.length; i += batchSize) {
      batches.push(tokenArray.slice(i, i + batchSize));
    }

    const sendBatch = (batchTokens) =>
      messaging.sendEachForMulticast({
        tokens: batchTokens,
        notification: { title, body },
        data: {
          type: "janaza",
          announcementId: context.params.announcementId,
          mosqueId,
          city,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "janaza_alerts_v2",
            sound: "janaza",
          },
        },
      });

    await Promise.all(batches.map(sendBatch));
    return null;
  });

/**
 * Trigger: notification_queue/{id} onCreate
 * Purpose: Processes broadcasts sent from the Admin Panel.
 */
exports.processNotificationQueue = functions.firestore
  .document("notification_queue/{id}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Safety check
    if (data.processed) return null;
    if (!data.to) {
        console.error("No target token (to) found in queue item:", context.params.id);
        return snap.ref.update({ error: "Missing FCM token", processed: true });
    }

    const message = {
      token: data.to,
      notification: {
        title: data.title,
        body: data.body,
      },
      data: data.data || {},
      android: {
        priority: "high",
        notification: {
          channelId: "push_alerts",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log("Successfully sent broadcast message:", response);

      return snap.ref.update({
        processed: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response
      });
    } catch (error) {
      console.error("Error sending broadcast message:", error);
      return snap.ref.update({
        error: error.message,
        processed: true,
        failedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
