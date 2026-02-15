// functions/index.js
// =========================
// CLEAN v2 VERSION (ADMIN via Custom Claims)
// =========================

const admin = require("firebase-admin");
const crypto = require("crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten, onDocumentUpdated } = require("firebase-functions/v2/firestore");

admin.initializeApp();
const db = admin.firestore();

// =========================
// Helpers
// =========================
function sha256Hex(input) {
  return crypto.createHash("sha256").update(String(input)).digest("hex");
}

function randDigits(n) {
  let out = "";
  for (let i = 0; i < n; i++) out += Math.floor(Math.random() * 10);
  return out;
}

function randToken(bytes = 24) {
  return crypto.randomBytes(bytes).toString("base64url"); // url-safe
}

// =========================
// 0) ONE-TIME: Make Admin (DEV ONLY)
// =========================
exports.makeAdmin = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    // 🔐 SUPER ADMIN UID (your UID)
    const SUPER_ADMIN_UID = "FwNZeS0HtaW2RTBBoK9LdwwIf5P2";
    if (request.auth.uid !== SUPER_ADMIN_UID) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    const targetUid = request.data?.uid;
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "Missing uid");
    }

    await admin.auth().setCustomUserClaims(targetUid, {
      admin: true,
    });

    return { ok: true };
  }
);

// =========================
// 1) Delivery verify (NO LOGIN) - HTTP endpoint
// POST body: { orderId, token, otp }
// =========================
exports.verifyDelivery = onRequest(
  {
    region: "us-central1",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
      }

      const { orderId, token, otp } = req.body || {};
      if (!orderId || !token || !otp) {
        return res.status(400).json({ error: "Missing fields" });
      }

      const orderRef = db.collection("orders").doc(String(orderId));
      const snap = await orderRef.get();

      if (!snap.exists) {
        return res.status(404).json({ error: "Order not found" });
      }

      const data = snap.data() || {};

      if (data.status !== "DELIVERY_OTP_SENT") {
        return res.status(400).json({ error: "Invalid order status" });
      }

      // verify delivery link token
      const tokenHash = sha256Hex("tok:" + token);
      if (tokenHash !== data.deliveryLinkTokenHash) {
        return res.status(401).json({ error: "Invalid delivery token" });
      }

      if (data.deliveryLinkUsed === true) {
        return res.status(400).json({ error: "Link already used" });
      }

      // verify drop OTP
      const otpHash = sha256Hex(`${otp}|${data.dropOtpSalt}`);
      if (otpHash !== data.dropOtpHash) {
        return res.status(401).json({ error: "Invalid OTP" });
      }

      if (data.dropOtpUsed === true) {
        return res.status(400).json({ error: "OTP already used" });
      }

      // mark delivered
      await orderRef.update({
        status: "DELIVERED",

        dropOtpUsed: true,
        dropOtpUsedAt: admin.firestore.FieldValue.serverTimestamp(),

        deliveryLinkUsed: true,
        deliveryLinkUsedAt: admin.firestore.FieldValue.serverTimestamp(),

        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveredBy: "delivery",

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.json({ success: true });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ error: "Server error" });
    }
  }
);

// =========================
// 2) Admin prepares drop (LOGIN + admin only)
// Callable (v2)
// =========================
exports.adminPrepareDrop = onCall(
  {
    region: "us-central1",
    enforceAppCheck: false, // DEV only
  },
  async (request) => {
    // 🔐 Login check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    // 🔐 Admin claim check
    const isAdmin = request.auth.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const uid = request.auth.uid;

    const orderId = String(request.data?.orderId || "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "Missing orderId");
    }

    const ref = db.collection("orders").doc(orderId);

    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }

      const o = snap.data() || {};

      if (o.status !== "PICKUP_CONFIRMED") {
        throw new HttpsError(
          "failed-precondition",
          "Order not in PICKUP_CONFIRMED"
        );
      }

      // prevent re-generate
      if (o.deliveryLinkTokenHash || o.dropOtpHash) {
        throw new HttpsError("failed-precondition", "Drop already prepared");
      }

      const token = randToken(24);
      const tokenHash = sha256Hex("tok:" + token);

      const dropOtp = randDigits(6);
      const salt = randToken(16);
      const dropOtpHash = sha256Hex(`${dropOtp}|${salt}`);

      tx.update(ref, {
        status: "DELIVERY_OTP_SENT",

        deliveryLinkTokenHash: tokenHash,
        deliveryLinkCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveryLinkUsed: false,

        dropOtpHash,
        dropOtpSalt: salt,
        dropOtpCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
        dropOtpUsed: false,

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid,
      });

      return {
        ok: true,
        orderId,
        deliveryLink: `https://yourdomain.com/d/${token}`, // TODO: replace domain
        dropOtp, // admin only
      };
    });
  }
);

function asNum(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === "number") return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function asStr(v) {
  return (v ?? "").toString().trim();
}

function asBool(v) {
  if (v === true || v === false) return v;
  const s = (v ?? "").toString().toLowerCase().trim();
  return s === "true" || s === "1" || s === "yes";
}

function asNullableBool(v) {
  if (v === null || v === undefined) return null;
  return asBool(v);
}

async function calculateProductBadges(productId, { force = false } = {}) {
  const productRef = db.collection("products").doc(String(productId));
  const productSnap = await productRef.get();
  if (!productSnap.exists) return;
  const product = productSnap.data() || {};
  const specs = product.specs || {};
  const badge = product.badge || {};
  const adminOverride = badge.adminOverride || {};
  if (!force && asBool(adminOverride.enabled)) return;
  const sellerId = asStr(product.sellerId);
  if (!sellerId) {
    await productRef.set(
      {
        badge: {
          recommended: false,
          trusted: false,
          calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );
    return;
  }
  const sellerSnap = await db.collection("users").doc(sellerId).get();
  const seller = sellerSnap.exists ? sellerSnap.data() || {} : {};

  const condition = asStr(specs.condition);
  const batteryPercent = asNum(specs.batteryPercent);
  const sellerRating = asNum(seller.sellerRating);
  const sellerDisputeCount = asNum(seller.sellerDisputeCount);
  const productFlagsCount = asNum(product.productFlagsCount);

  const condOk = condition === "Brand New" || condition === "Like New";
  const batteryOk = batteryPercent === null ? true : batteryPercent >= 90;
  const ratingOk = sellerRating !== null && sellerRating >= 4.5;
  const disputeOk = sellerDisputeCount !== null && sellerDisputeCount === 0;
  const productFlagsOk = productFlagsCount !== null && productFlagsCount === 0;

  const recommended = condOk && batteryOk && ratingOk && disputeOk && productFlagsOk;

  const sellerTrusted = asBool(seller.sellerTrusted);
  let trusted = false;
  if (sellerTrusted) {
    trusted = true;
  } else {
    const sellerCompletedOrders = asNum(seller.sellerCompletedOrders);
    const sellerCancelledOrders = asNum(seller.sellerCancelledOrders);
    const createdAt = seller.createdAt instanceof admin.firestore.Timestamp
      ? seller.createdAt.toDate()
      : null;
    const ageDays = createdAt ? Math.floor((Date.now() - createdAt.getTime()) / 86400000) : null;
    const completedOk =
      sellerCompletedOrders !== null && sellerCompletedOrders >= 10;
    const cancelledOk =
      sellerCancelledOrders !== null && sellerCancelledOrders === 0;
    const disputesOk = sellerDisputeCount !== null && sellerDisputeCount === 0;
    const ageOk = ageDays !== null && ageDays >= 90;
    trusted = completedOk && cancelledOk && disputesOk && ageOk;
  }

  await productRef.set(
    {
      badge: {
        recommended,
        trusted,
        calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    { merge: true }
  );
}

async function writeBadgeAuditLog({
  productId,
  sellerId,
  action,
  previousState,
  newState,
  reason,
  adminId,
  adminName,
}) {
  await db.collection("badge_audit_logs").add({
    productId,
    sellerId,
    action,
    previousState,
    newState,
    reason,
    adminId,
    adminName,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

exports.adminSetProductBadgeOverride = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const isAdmin = request.auth.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const productId = asStr(request.data?.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "Missing productId");
    }
    const reason = asStr(request.data?.reason);
    if (!reason) {
      throw new HttpsError("invalid-argument", "Missing reason");
    }
    const rec = request.data?.recommended;
    const tr = request.data?.trusted;
    const recommended = rec === null || rec === undefined ? null : asBool(rec);
    const trusted = tr === null || tr === undefined ? null : asBool(tr);

    const productRef = db.collection("products").doc(productId);
    const productSnap = await productRef.get();
    if (!productSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = productSnap.data() || {};
    const sellerId = asStr(product.sellerId);
    const badge = product.badge || {};
    const adminOverride = badge.adminOverride || {};
    const prevState = {
      enabled: asBool(adminOverride.enabled),
      recommended: asNullableBool(adminOverride.recommended),
      trusted: asNullableBool(adminOverride.trusted),
    };

    const adminId = request.auth.uid;
    const adminDoc = await db.collection("users").doc(adminId).get();
    const adminName = asStr(adminDoc.data()?.name) || "Admin";

    const effectiveRecommended =
      recommended !== null ? recommended : asBool(badge.recommended);
    const effectiveTrusted =
      trusted !== null ? trusted : asBool(badge.trusted);

    await productRef.set(
      {
        badge: {
          recommended: effectiveRecommended,
          trusted: effectiveTrusted,
          calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
          adminOverride: {
            enabled: true,
            recommended,
            trusted,
            reason,
            adminId,
            adminName,
            overriddenAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
      },
      { merge: true }
    );

    const newState = {
      enabled: true,
      recommended,
      trusted,
    };
    const action = prevState.enabled ? "OVERRIDE_UPDATED" : "OVERRIDE_ENABLED";
    await writeBadgeAuditLog({
      productId,
      sellerId,
      action,
      previousState: prevState,
      newState,
      reason,
      adminId,
      adminName,
    });

    return { ok: true };
  }
);

exports.adminDisableProductBadgeOverride = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const isAdmin = request.auth.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const productId = asStr(request.data?.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "Missing productId");
    }

    const productRef = db.collection("products").doc(productId);
    const productSnap = await productRef.get();
    if (!productSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = productSnap.data() || {};
    const sellerId = asStr(product.sellerId);
    const badge = product.badge || {};
    const adminOverride = badge.adminOverride || {};
    const prevState = {
      enabled: asBool(adminOverride.enabled),
      recommended: asNullableBool(adminOverride.recommended),
      trusted: asNullableBool(adminOverride.trusted),
    };

    const adminId = request.auth.uid;
    const adminDoc = await db.collection("users").doc(adminId).get();
    const adminName = asStr(adminDoc.data()?.name) || "Admin";
    const reason = "Override disabled";

    await productRef.set(
      {
        badge: {
          adminOverride: {
            enabled: false,
            recommended: adminOverride.recommended ?? null,
            trusted: adminOverride.trusted ?? null,
            reason: adminOverride.reason ?? "",
            adminId: adminOverride.adminId ?? "",
            adminName: adminOverride.adminName ?? "",
            overriddenAt: adminOverride.overriddenAt ?? null,
          },
        },
      },
      { merge: true }
    );

    await calculateProductBadges(productId, { force: true });

    const newState = {
      enabled: false,
      recommended: asNullableBool(adminOverride.recommended),
      trusted: asNullableBool(adminOverride.trusted),
    };
    await writeBadgeAuditLog({
      productId,
      sellerId,
      action: "OVERRIDE_DISABLED",
      previousState: prevState,
      newState,
      reason,
      adminId,
      adminName,
    });

    return { ok: true };
  }
);

exports.recalculateProductBadges = onCall(
  { region: "us-central1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }
    const isAdmin = request.auth.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }
    const productId = asStr(request.data?.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "Missing productId");
    }
    await calculateProductBadges(productId);
    return { ok: true };
  }
);

exports.onProductBadgeRecalculate = onDocumentWritten(
  { region: "us-central1", document: "products/{productId}" },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return;
    const before = event.data?.before;
    const afterData = after.data() || {};
    const afterSpecs = afterData.specs || {};

    if (before && before.exists) {
      const beforeData = before.data() || {};
      const beforeSpecs = beforeData.specs || {};
      const pick = (d, s) => ({
        sellerId: asStr(d.sellerId),
        condition: asStr(s.condition),
        batteryPercent: asNum(s.batteryPercent),
        productFlagsCount: asNum(d.productFlagsCount),
      });
      const prev = pick(beforeData, beforeSpecs);
      const next = pick(afterData, afterSpecs);
      if (JSON.stringify(prev) === JSON.stringify(next)) return;
    }

    await calculateProductBadges(after.id);
  }
);

exports.onOrderCompletedRecalculateBadges = onDocumentUpdated(
  { region: "us-central1", document: "orders/{orderId}" },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const beforeStatus = asStr(before.status).toUpperCase();
    const afterStatus = asStr(after.status).toUpperCase();
    const completed = afterStatus === "DELIVERED" || afterStatus === "SETTLED";
    if (!completed || beforeStatus === afterStatus) return;
    const productId = asStr(after.productId);
    if (!productId) return;
    await calculateProductBadges(productId);
  }
);
