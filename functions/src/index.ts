import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onDocumentWritten, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import sharp from "sharp";
import ngeohash from "ngeohash";
import { randomUUID } from "crypto";


const placesApiKey = defineSecret("PLACES_API_KEY");

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

export const onUsernameReserve = onCall(
  { enforceAppCheck: true },
  async (request) => {
  const { username } = request.data;
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");
  if (!username || username.length < 3 || username.length > 20) {
    throw new HttpsError("invalid-argument", "Username must be 3-20 characters");
  }
  if (!/^[a-z0-9_]+$/.test(username)) {
    throw new HttpsError("invalid-argument", "Lowercase letters, numbers, underscores only");
  }

  const ref = db.collection("usernames").doc(username);
  const userRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (doc.exists) throw new HttpsError("already-exists", "Username taken");
      tx.set(ref, { uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.set(userRef, { username }, { merge: true });
    });
    return { success: true, username };
  } catch (e: any) {
    if (e.code === "already-exists") throw e;
    logger.error("onUsernameReserve failed", { error: e.message, code: e.code, stack: e.stack });
    throw new HttpsError("internal", "Failed to reserve username");
  }
});

export const onPhotoUpload = onObjectFinalized(async (event) => {
  const filePath = event.data.name;
  if (!filePath || filePath.includes("thumb_") || !filePath.startsWith("drinks/")) return;

  const bucket = storage.bucket(event.data.bucket);
  const file = bucket.file(filePath);
  const [buffer] = await file.download();

  const thumbnail = await sharp(buffer).resize(200, 200, { fit: "cover" }).jpeg({ quality: 80 }).toBuffer();

  const dir = filePath.substring(0, filePath.lastIndexOf("/"));
  const name = filePath.substring(filePath.lastIndexOf("/") + 1);
  const thumbPath = `${dir}/thumb_${name}`;
  const thumbFile = bucket.file(thumbPath);

  const token = randomUUID();
  await thumbFile.save(thumbnail, {
    metadata: { contentType: "image/jpeg", metadata: { firebaseStorageDownloadTokens: token } },
  });

  const bucketName = thumbFile.bucket.name;
  const encodedPath = encodeURIComponent(thumbPath);
  const thumbUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${token}`;
  logger.info(`Thumbnail created: ${thumbUrl}`);
});

export const onRankingWrite = onDocumentWritten(
  "users/{uid}/rankings/{placeId}",
  async (event) => {
    const uid = event.params.uid;
    const rankingsRef = db.collection("users").doc(uid).collection("rankings");
    const snapshot = await rankingsRef.get();

    let totalDrinks = 0;
    let totalScore = 0;
    const tierCounts: Record<string, number> = {};

    snapshot.forEach((doc) => {
      const data = doc.data();
      totalDrinks += data.drinkCount || 0;
      totalScore += (data.avgDrinkScore || 0) * (data.drinkCount || 0);
      tierCounts[data.tier] = (tierCounts[data.tier] || 0) + 1;
    });

    const avgScore = totalDrinks > 0 ? Math.round((totalScore / totalDrinks) * 10) / 10 : 0;
    const mostCommonTier = Object.entries(tierCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || "S";

    await db.collection("users").doc(uid).update({
      "stats.shopsRanked": snapshot.size,
      "stats.drinksRated": totalDrinks,
      "stats.avgScore": avgScore,
      "stats.mostCommonTier": mostCommonTier,
    });

    if (!event.data?.after?.exists) return;

    const friendships1 = await db.collection("friendships")
      .where("uid1", "==", uid).where("status", "==", "accepted").get();
    const friendships2 = await db.collection("friendships")
      .where("uid2", "==", uid).where("status", "==", "accepted").get();

    const friendUids = new Set<string>();
    friendships1.forEach((d) => friendUids.add(d.data().uid2));
    friendships2.forEach((d) => friendUids.add(d.data().uid1));

    const rankingData = event.data.after.data();
    const promises: Promise<any>[] = [];

    for (const friendUid of friendUids) {
      const userDoc = await db.collection("users").doc(friendUid).get();
      const token = userDoc.data()?.fcmToken;
      if (!token) continue;

      promises.push(
        admin.messaging().send({
          token,
          notification: {
            title: `${rankingData?.shopName || "A shop"} was just ranked!`,
            body: `Your friend gave it ${rankingData?.tier} tier`,
          },
          data: { type: "ranking", placeId: event.params.placeId },
        }).catch(() => {})
      );
    }
    await Promise.all(promises);
  }
);

export const onFriendAccepted = onDocumentUpdated(
  "friendships/{docId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status === "pending" && after.status === "accepted") {
      const initiatorDoc = await db.collection("users").doc(after.initiatedBy).get();
      const token = initiatorDoc.data()?.fcmToken;
      if (!token) return;

      const acceptorUid = after.initiatedBy === after.uid1 ? after.uid2 : after.uid1;
      const acceptorDoc = await db.collection("users").doc(acceptorUid).get();
      const name = acceptorDoc.data()?.displayName || "Someone";

      await admin.messaging().send({
        token,
        notification: {
          title: "Friend request accepted!",
          body: `${name} accepted your friend request`,
        },
        data: { type: "friend_accepted", friendUid: acceptorUid },
      }).catch(() => {});
    }
  }
);

export const onNearbySearch = onCall(
  { secrets: [placesApiKey], enforceAppCheck: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

    const { latitude, longitude } = request.data;
    if (typeof latitude !== "number" || typeof longitude !== "number") {
      throw new HttpsError("invalid-argument", "latitude and longitude required");
    }

    const geohash = ngeohash.encode(latitude, longitude, 6);
    const cacheRef = db.collection("nearbyCache").doc(geohash);
    const cacheDoc = await cacheRef.get();

    if (cacheDoc.exists) {
      const data = cacheDoc.data()!;
      const fetchedAt = data.fetchedAt?.toDate();
      if (fetchedAt && Date.now() - fetchedAt.getTime() < 24 * 60 * 60 * 1000) {
        return { shops: data.shops };
      }
    }

    const url = new URL("https://maps.googleapis.com/maps/api/place/nearbysearch/json");
    url.searchParams.set("location", `${latitude},${longitude}`);
    url.searchParams.set("radius", "1500");
    url.searchParams.set("keyword", "boba tea bubble tea");
    url.searchParams.set("key", placesApiKey.value());

    const res = await fetch(url.toString());
    if (!res.ok) {
      logger.error(`Places API error: ${res.status}`);
      throw new HttpsError("internal", "Places API request failed");
    }

    const body = await res.json() as {
      results?: Array<Record<string, any>>;
      status?: string;
      error_message?: string;
    };

    if (body.status !== "OK" && body.status !== "ZERO_RESULTS") {
      logger.error(`Places API status: ${body.status} — ${body.error_message ?? ""}`);
      throw new HttpsError("internal", `Places API error: ${body.status}`);
    }

    const results = body.results ?? [];

    const shops = results.map((place) => {
      const loc = place.geometry?.location ?? {};
      return {
        placeId: place.place_id ?? "",
        name: place.name ?? "",
        lat: loc.lat ?? 0,
        lng: loc.lng ?? 0,
        googleRating: place.rating ?? 0,
        reviewCount: place.user_ratings_total ?? 0,
        vicinity: place.vicinity ?? "",
        openNow: place.opening_hours?.open_now ?? null,
      };
    });

    if (shops.length > 0) {
      await cacheRef.set({
        shops,
        fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { shops };
  }
);

export const onPlaceDetail = onCall(
  { secrets: [placesApiKey], enforceAppCheck: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

    const { placeId } = request.data;
    if (!placeId || typeof placeId !== "string") {
      throw new HttpsError("invalid-argument", "placeId required");
    }

    const shopRef = db.collection("shops").doc(placeId);
    const shopDoc = await shopRef.get();

    if (shopDoc.exists) {
      const data = shopDoc.data()!;
      const syncedAt = data.lastSyncedAt?.toDate();
      const isFresh = syncedAt && Date.now() - syncedAt.getTime() < 24 * 60 * 60 * 1000;
      if (isFresh && data.photoUrl) {
        return { shop: data };
      }
    }

    const url = new URL("https://maps.googleapis.com/maps/api/place/details/json");
    url.searchParams.set("place_id", placeId);
    url.searchParams.set("fields", "name,formatted_address,formatted_phone_number,website,opening_hours,geometry,rating,user_ratings_total,photos");
    url.searchParams.set("key", placesApiKey.value());

    const res = await fetch(url.toString());
    if (!res.ok) {
      logger.error(`Place Details API error: ${res.status}`);
      throw new HttpsError("internal", "Place Details API request failed");
    }

    const body = await res.json() as {
      result?: Record<string, any>;
      status?: string;
      error_message?: string;
    };

    if (body.status !== "OK") {
      logger.error(`Place Details API status: ${body.status} — ${body.error_message ?? ""}`);
      throw new HttpsError("internal", `Place Details API error: ${body.status}`);
    }

    const place = body.result ?? {};
    const loc = place.geometry?.location ?? {};

    let photoUrl: string | null = null;
    const photoRef = place.photos?.[0]?.photo_reference;
    if (photoRef) {
      try {
        const photoApiUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=${photoRef}&key=${placesApiKey.value()}`;
        const photoRes = await fetch(photoApiUrl, { redirect: "follow" });
        if (photoRes.ok) {
          const arrayBuf = await photoRes.arrayBuffer();
          const photoBuffer = Buffer.from(arrayBuf);
          const storagePath = `shop_photos/${placeId}.jpg`;
          const bucket = storage.bucket();
          const file = bucket.file(storagePath);
          const token = randomUUID();
          await file.save(photoBuffer, {
            metadata: { contentType: "image/jpeg", metadata: { firebaseStorageDownloadTokens: token } },
          });
          const encodedPath = encodeURIComponent(storagePath);
          photoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;
        }
      } catch (e) {
        logger.warn(`Failed to download shop photo for ${placeId}`, e);
      }
    }

    const shopData: Record<string, any> = {
      name: place.name ?? "",
      address: place.formatted_address ?? "",
      coordinates: { lat: loc.lat ?? 0, lng: loc.lng ?? 0 },
      googleRating: place.rating ?? 0,
      reviewCount: place.user_ratings_total ?? 0,
      website: place.website ?? null,
      phoneNumber: place.formatted_phone_number ?? null,
      photoUrl,
      openingHours: {
        periods: (place.opening_hours?.periods ?? []).map((p: any) => ({
          open: { day: p.open?.day ?? 0, time: p.open?.time ?? "0000" },
          close: { day: p.close?.day ?? 0, time: p.close?.time ?? "2359" },
        })),
        weekdayText: place.opening_hours?.weekday_text ?? [],
      },
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await shopRef.set(shopData, { merge: true });
    return { shop: shopData };
  }
);

export const scheduledCacheRefresh = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/Los_Angeles" },
  async () => {
    const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000);
    const stale = await db.collection("shops")
      .where("lastSyncedAt", "<", cutoff)
      .limit(50)
      .get();

    logger.info(`Found ${stale.size} stale shop cache entries to refresh`);
  }
);
