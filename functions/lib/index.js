"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPresenceChanged = exports.onReviewCreated = exports.onAnnouncementCreated = exports.runImeiCheck = exports.onProductImeiRejected = exports.autoFreezePendingFees = exports.onNewReport = exports.onNewChatMessage = exports.onUserVerificationDocUploaded = exports.onModelRequestStatusChanged = exports.onNewModelRequest = exports.onUserRoleChanged = exports.onFeeProofSubmitted = exports.onDepositReturned = exports.onNewImeiSubmission = exports.onNewOrder = exports.sendNotification = exports.onOrderStatusChanged = exports.onOrderCompleted = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const auth_1 = require("firebase-admin/auth");
admin.initializeApp();
const db = (0, firestore_1.getFirestore)();
// urlToStoragePath + deleteStorageFile — removed: product images are kept for order history
async function sendFcmSafe(token, userId, message) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o;
    try {
        const fullMessage = Object.assign(Object.assign({}, message), { token });
        // ✅ iOS Fix: Ensure APNs payload includes 'alert' dictionary containing title & body.
        // When apns.payload.aps is specified without 'alert', APNs plays sound/updates badge
        // but DOES NOT display any text banner on the iOS screen!
        if (message.notification) {
            const title = (_a = message.notification.title) !== null && _a !== void 0 ? _a : "Sigma Moby";
            const body = (_b = message.notification.body) !== null && _b !== void 0 ? _b : "";
            const existingAps = (_e = (_d = (_c = message.apns) === null || _c === void 0 ? void 0 : _c.payload) === null || _d === void 0 ? void 0 : _d.aps) !== null && _e !== void 0 ? _e : {};
            fullMessage.apns = Object.assign(Object.assign({}, message.apns), { headers: Object.assign({ "apns-priority": "10" }, ((_g = (_f = message.apns) === null || _f === void 0 ? void 0 : _f.headers) !== null && _g !== void 0 ? _g : {})), payload: Object.assign(Object.assign({}, ((_j = (_h = message.apns) === null || _h === void 0 ? void 0 : _h.payload) !== null && _j !== void 0 ? _j : {})), { aps: Object.assign(Object.assign({}, existingAps), { alert: {
                            title,
                            body,
                        }, sound: (_k = existingAps.sound) !== null && _k !== void 0 ? _k : "default" }) }) });
        }
        await (0, messaging_1.getMessaging)().send(fullMessage);
    }
    catch (e) {
        const code = (_o = (_m = (_l = e === null || e === void 0 ? void 0 : e.errorInfo) === null || _l === void 0 ? void 0 : _l.code) !== null && _m !== void 0 ? _m : e === null || e === void 0 ? void 0 : e.code) !== null && _o !== void 0 ? _o : "";
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token") {
            functions.logger.warn(`Stale FCM token for ${userId}, clearing`);
            await db.collection("users").doc(userId)
                .update({ fcmToken: "" })
                .catch(() => { });
        }
        else {
            functions.logger.warn(`FCM failed for ${userId}`, e);
        }
    }
}
/* =========================================================
   onOrderCompleted
   Trigger: orders/{orderId} document ကို write လုပ်တိုင်း run
   Condition: status "COMPLETED" ဖြစ်သွားမှ (မဟုတ်ရင် early exit)

   လုပ်ဆောင်ချက်:
   1. seller totalSales + pendingFee + feeDeadline update
   2. product document delete
   3. imei_registry document delete
   4. Storage files cleanup (images + imeiPhoto)
   5. buyer + seller ကို notification ပို့
========================================================= */
exports.onOrderCompleted = functions
    .region("asia-southeast1") // Singapore — Myanmar နဲ့ နီးဆုံး
    .firestore.document("orders/{orderId}")
    .onWrite(async (change, context) => {
    var _a, _b, _c;
    const after = change.after.data();
    const before = change.before.data();
    // ── early exits ──────────────────────────────────────────────────────────
    if (!after)
        return; // delete event — ကိုင်တွယ်စရာမလို
    if ((before === null || before === void 0 ? void 0 : before.status) === after.status)
        return; // status မပြောင်းရင် skip
    if (after.status !== "COMPLETED")
        return; // COMPLETED မဟုတ်ရင် skip
    // ── Idempotency guard ────────────────────────────────────────────────────
    // Firebase may re-trigger this function (at-least-once delivery).
    // completionProcessed flag prevents double totalSales increment.
    if (after.completionProcessed === true) {
        functions.logger.warn(`onOrderCompleted: already processed, skipping`, { orderId: context.params.orderId });
        return;
    }
    const orderId = context.params.orderId;
    const sellerId = (_a = after.sellerId) !== null && _a !== void 0 ? _a : "";
    const productId = (_b = after.productId) !== null && _b !== void 0 ? _b : "";
    const imeiFull = (_c = after.imeiFull) !== null && _c !== void 0 ? _c : "";
    functions.logger.info(`onOrderCompleted triggered`, {
        orderId,
        sellerId,
        productId,
        imeiFull,
    });
    // Mark as processed immediately to guard against re-trigger.
    try {
        await db.collection("orders").doc(orderId).update({
            completionProcessed: true,
        });
    }
    catch (e) {
        functions.logger.error(`Failed to set completionProcessed on order ${orderId}`, e);
        // Don't abort — continue processing; worst case is a retry that hits the guard above.
    }
    // ── 1. seller totalSales ──────────────────────────────────────────────────
    // Admin SDK ကိုသုံး → Firestore rules bypass
    // NOTE: pendingFee / feeDeadline ကို ဒီနေရာ မလုပ်တော့
    //   → FEE_PENDING stage မှာ buyer confirm လုပ်သောအခါ platformFee သတ်မှတ်ပြီးသား
    //   → adminConfirmFeeReceived (client) က pendingFee=0 / feeDeadline=null ပြန်ဖျက်ပြီးသား
    //   → ဒီနေရာမှာ ထပ်ကိုင်ရင် double-count ဖြစ်မည်
    if (sellerId) {
        try {
            await db.collection("users").doc(sellerId).update({
                totalSales: firestore_1.FieldValue.increment(1),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            functions.logger.info(`seller ${sellerId} updated: totalSales+1`);
        }
        catch (e) {
            functions.logger.error(`seller update failed for ${sellerId}`, e);
        }
    }
    // ── 2. product → active:false (sold, hidden from public; history preserved) ─
    if (productId) {
        try {
            await db.collection("products").doc(productId).update({
                active: false,
                hasActiveOrder: false,
                activeOrderId: firestore_1.FieldValue.delete(),
                soldAt: firestore_1.FieldValue.serverTimestamp(),
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            functions.logger.info(`Product ${productId} marked as sold (active=false)`);
        }
        catch (e) {
            functions.logger.error(`Product update failed: ${productId}`, e);
        }
    }
    // ── 3. imei_registry delete — imeiFull သို့မဟုတ် productId ဖြင့် ရှာဖျက်မည် ──
    try {
        if (imeiFull) {
            // IMEI နံပါတ် သိရင် တိုက်ရိုက်ဖျက်မယ် (doc ID က IMEI ပါ)
            await db.collection("imei_registry").doc(imeiFull).delete();
            functions.logger.info(`imei_registry deleted directly by imei: ${imeiFull}`);
        }
        else if (productId) {
            // IMEI မသိရင် productId နဲ့ query လုပ်ပြီး ဖျက်မယ်
            const imeiSnap = await db.collection("imei_registry")
                .where("productId", "==", productId)
                .get();
            for (const doc of imeiSnap.docs) {
                await doc.ref.delete();
                functions.logger.info(`imei_registry deleted by productId: ${doc.id}`);
            }
        }
    }
    catch (e) {
        functions.logger.error(`imei_registry delete process failed`, e);
    }
    // ── 4. Storage files → မဖျက် ────────────────────────────────────────────
    // Product ကို ဖျက်မတော့သောကြောင့် images/imeiPhoto ဆက်သိမ်းထားမည်
    // Seller/Buyer order history မှ ပုံကြည့်လို့ ရမည်
    // ── 5. Notifications ─────────────────────────────────────────────────────
    // onOrderStatusChanged (COMPLETED trigger) က buyer + seller နှစ်ဦးလုံးကို
    // Firestore in-app + FCM ပို့သောကြောင့် ဤနေရာမှ duplicate မဖြစ်အောင် မရေးတော့
    return;
});
/* =========================================================
   onOrderStatusChanged — FCM Push + In-app Notification
   Order status ပြောင်းတိုင်း buyer/seller ဆီ Firestore in-app + FCM
   (Flutter client side duplicate calls မလိုတော့)
========================================================= */
exports.onOrderStatusChanged = functions
    .region("asia-southeast1")
    .firestore.document("orders/{orderId}")
    .onWrite(async (change) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    if (before.status === after.status)
        return;
    const orderId = change.after.id;
    const sellerId = (_a = after.sellerId) !== null && _a !== void 0 ? _a : "";
    const buyerId = (_b = after.buyerId) !== null && _b !== void 0 ? _b : "";
    const status = (_c = after.status) !== null && _c !== void 0 ? _c : "";
    const productName = (_d = after.productName) !== null && _d !== void 0 ? _d : "ပစ္စည်း";
    // Status → per-role message map
    // DEPOSIT_APPROVED — buyer + seller နှစ်ဦးလုံး (seller: ယခု ship လုပ်နိုင်)
    const statusMessages = {
        DEPOSIT_APPROVED: {
            buyerTitle: "ငွေပေးချေမှု အတည်ပြုပါပြီ ✅",
            buyerBody: `${productName} — seller မှ ပို့ဆောင်ရန် ပြင်ဆင်နေပါပြီ`,
            sellerTitle: "Deposit Approve ဖြစ်ပါပြီ ✅",
            sellerBody: `${productName} — ယခု ship လုပ်နိုင်ပါပြီ`,
        },
        REJECTED: {
            buyerTitle: "Order ပယ်ချခြင်း ❌",
            buyerBody: `${productName} — ငွေပေးချေမှု မအတည်ပြုနိုင်ပါ`,
        },
        ON_THE_WAY: {
            buyerTitle: "ပို့ဆောင်နေပါပြီ 🚚",
            buyerBody: `${productName} — လမ်းခုလတ်မှာ ရှိနေပါပြီ — လက်ခံရရင် confirm လုပ်ပေးပါ`,
        },
        // FEE_PENDING — buyer confirm receipt လုပ်ပြီ၊ admin deposit ပြန်လွှဲပြီး seller 3ရက်အတွင်း fee ပေးရမည်
        FEE_PENDING: {
            sellerTitle: "ပစ္စည်း Buyer လက်ခံပြီး ⚠️",
            sellerBody: `${productName} — Buyer deposit ပြန်လွှဲပြီး — Service charge ကို ၃ ရက်အတွင်း လွှဲပေးပါ`,
            buyerTitle: "ပစ္စည်း လက်ခံပြီး ✅",
            buyerBody: `${productName} — Admin မှ Deposit ပြန်လွှဲပေးပါမည်`,
        },
        // COMPLETED — admin က fee confirm ပြီး၊ order အပြည့်အဝ ပြီးစီး
        COMPLETED: {
            sellerTitle: "Service charge လက်ခံပြီး 🎉",
            sellerBody: `${productName} — Order ပြီးစီးပါပြီ၊ ကျေးဇူးတင်ပါသည်`,
            buyerTitle: "Order ပြီးစီးပါပြီ 🎉",
            buyerBody: `${productName} — Order အပြည့်အဝ ပြီးစီးပါပြီ`,
        },
        CANCELLED: {
            sellerTitle: "Order ပယ်ဖျက်ပြီး",
            sellerBody: `${productName} — ဝယ်သူမှ order ပယ်ဖျက်ပါသည်`,
        },
        REFUNDED: {
            buyerTitle: "Deposit ပြန်အမ်းပါပြီ 💰",
            buyerBody: `${productName} — deposit refund လုပ်ဆောင်ပြီးပါပြီ`,
            sellerTitle: (after.refundedTo === 'seller') ? "Delivery ခ ပြန်လွှဲပြီးပါပြီ 💰" : "Deposit Refund ပြုလုပ်ပြီး 💰",
            sellerBody: (after.refundedTo === 'seller') ? `${productName} — သင့်ထံ delivery ခ ပြန်လွှဲပေးလိုက်ပါပြီ` : `${productName} — buyer ဆီ deposit ပြန်အမ်းပြီးပါပြီ`,
        },
        RETURN_PENDING: {
            buyerTitle: "Return Request တင်ပြီးပါပြီ 🚩",
            buyerBody: `${productName} — Admin မှ စစ်ဆေးပေးပါမည်`,
            sellerTitle: "Buyer မှ ပစ္စည်းပြန်ပေးရန် Request တင်ထားသည် ⚠️",
            sellerBody: `${productName} — အချက်အလက်မကိုက်ညီ၍ Return ပြန်ပို့ရန် တင်ထားပါသည်`,
        },
        RETURN_REJECTED: {
            buyerTitle: "ပို့ဆောင်မှု မအောင်မြင်သဖြင့် Deposit ဆုံးရှုံးပါသည် ⚠️",
            buyerBody: `${productName} — ဝယ်သူကို ဆက်သွယ်မရသဖြင့် ပစ္စည်းပြန်ရောက်လာပြီး Deposit အား Delivery ခ အဖြစ် အသုံးပြုလိုက်ပါသည်`,
            sellerTitle: "Delivery ခ Claim လုပ်နိုင်ပါပြီ 💰",
            sellerBody: `${productName} — ပို့ဆောင်မှုမအောင်မြင်သဖြင့် Delivery ခ Claim တင်ပေးပါ`,
        },
        RETURN_CLAIMED: {
            sellerTitle: "Delivery ခ Claim တင်ပြီးပါပြီ ✅",
            sellerBody: `${productName} — Admin မှ စစ်ဆေးပြီး Delivery ခ ပြန်လွှဲပေးပါမည်`,
        },
        SELLER_REJECTED: {
            buyerTitle: "ရောင်းသူမှ Order ပယ်ဖျက်လိုက်ပါသည် ⚠️",
            buyerBody: `${productName} — ပို့ဆောင်ရန် အဆင်မပြေပါသဖြင့် seller မှ ပယ်ဖျက်လိုက်ပါသည် (Admin မှ deposit ပြန်အမ်းပေးပါမည်)`,
            sellerTitle: "Order ပယ်ဖျက်ပြီးပါပြီ ✅",
            sellerBody: `${productName} — ပို့ဆောင်ရန် အဆင်မပြေသော order ကို ပယ်ဖျက်လိုက်ပါပြီ`,
        },
    };
    // ── hasActiveOrder field clear (terminal statuses) ──────────────────────
    const productId = (_e = after.productId) !== null && _e !== void 0 ? _e : "";
    const terminalStatuses = ["CANCELLED", "REJECTED", "REFUNDED", "SELLER_REJECTED"];
    if (productId && terminalStatuses.includes(status)) {
        try {
            // ✅ If refund is due to a RETURN_PENDING request, keep the product inactive (seller issue).
            // Otherwise (cancel/reject), reactivate it.
            const prevStatus = (_f = before.status) !== null && _f !== void 0 ? _f : "";
            const shouldBeActive = prevStatus !== "RETURN_PENDING";
            await db.collection("products").doc(productId).update({
                hasActiveOrder: false,
                active: shouldBeActive,
                activeOrderId: firestore_1.FieldValue.delete(),
            });
            functions.logger.info(`Product ${productId} unlock: active=${shouldBeActive} (prevStatus=${prevStatus})`);
        }
        catch (e) {
            functions.logger.warn(`hasActiveOrder clear failed for ${productId}`, e);
        }
    }
    // ── pendingFee / feeDeadline — FEE_PENDING ────────────────────────────
    // Buyer confirm receipt (ON_THE_WAY → FEE_PENDING) ဖြစ်တိုင်း
    // seller.pendingFee += platformFee, seller.feeDeadline = now + 3 days
    if (status === "FEE_PENDING" && sellerId) {
        const platformFee = (_g = after.platformFee) !== null && _g !== void 0 ? _g : 0;
        if (platformFee > 0) {
            try {
                const sellerRef = db.collection("users").doc(sellerId);
                await db.runTransaction(async (tx) => {
                    var _a;
                    const sellerSnap = await tx.get(sellerRef);
                    if (!sellerSnap.exists)
                        return;
                    const sellerData = sellerSnap.data();
                    const currentFee = (_a = sellerData.pendingFee) !== null && _a !== void 0 ? _a : 0;
                    // ပထမဆုံး pendingFee မဟုတ်ရင် ရှိပြီးသား deadline မပြောင်း
                    const feeDeadline = currentFee > 0
                        ? sellerData.feeDeadline
                        : firestore_1.Timestamp.fromDate(new Date(Date.now() + 3 * 24 * 60 * 60 * 1000));
                    tx.update(sellerRef, {
                        pendingFee: firestore_1.FieldValue.increment(platformFee),
                        feeDeadline,
                        updatedAt: firestore_1.FieldValue.serverTimestamp(),
                    });
                });
                functions.logger.info(`FEE_PENDING: seller ${sellerId} pendingFee +${platformFee}, deadline set`);
            }
            catch (e) {
                functions.logger.error(`FEE_PENDING: pendingFee update failed for seller ${sellerId}`, e);
            }
        }
    }
    // ── feeFreeze clear — COMPLETED ───────────────────────────────────────
    // Admin fee confirm ပြီး (FEE_PENDING → COMPLETED) ဖြစ်သောအခါ
    // seller.listingsFrozen = false (autoFreezePendingFees က set ထားခဲ့ရင် ဖျက်ပေး)
    if (status === "COMPLETED" && sellerId) {
        try {
            const batch = db.batch();
            const sellerRef = db.collection("users").doc(sellerId);
            // 1. Unfreeze seller
            batch.update(sellerRef, {
                listingsFrozen: false,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            // 2. Reactivate only non-sold products
            const productsSnap = await db.collection("products")
                .where("sellerId", "==", sellerId)
                .get();
            for (const productDoc of productsSnap.docs) {
                const pData = productDoc.data();
                // ✅ Fee ကြောင့် ပိတ်ထားခဲ့တဲ့ ပစ္စည်း (deactivatedByFeeFreeze) ကိုသာ ပြန်ဖွင့်ပေးပါမည်
                if (pData.deactivatedByFeeFreeze === true) {
                    batch.update(productDoc.ref, {
                        active: true,
                        deactivatedByFeeFreeze: firestore_1.FieldValue.delete(),
                        updatedAt: firestore_1.FieldValue.serverTimestamp(),
                    });
                }
            }
            await batch.commit();
            functions.logger.info(`COMPLETED: listingsFrozen cleared and products reactivated for seller ${sellerId}`);
        }
        catch (e) {
            functions.logger.warn(`COMPLETED: unfreeze process failed for ${sellerId}`, e);
        }
    }
    const msgConfig = statusMessages[status];
    if (!msgConfig)
        return;
    // Build target list: { userId, title, body, targetRole }
    const targets = [];
    if (buyerId && msgConfig.buyerTitle && msgConfig.buyerBody) {
        targets.push({ userId: buyerId, title: msgConfig.buyerTitle, body: msgConfig.buyerBody, targetRole: "buyer" });
    }
    const isSellerVisible = after.sellerVisible === true;
    if (sellerId && msgConfig.sellerTitle && msgConfig.sellerBody && isSellerVisible) {
        targets.push({ userId: sellerId, title: msgConfig.sellerTitle, body: msgConfig.sellerBody, targetRole: "seller" });
    }
    // ── Admin notification — admin မလုပ်တဲ့ action တွေ (others) အတွက်သာ ────────
    // DEPOSIT_APPROVED / REJECTED / REFUNDED → admin ကိုယ်တိုင် လုပ်တာ → notify မလို
    const buyerName = (_h = after.buyerName) !== null && _h !== void 0 ? _h : "Buyer";
    const sellerName = (_j = after.sellerName) !== null && _j !== void 0 ? _j : "Seller";
    const adminNotifyStatuses = {
        ON_THE_WAY: {
            title: "🚚 Order Ship လုပ်ပြီ",
            body: `${sellerName} မှ ${productName} ကို Ship လုပ်ပြီးပါပြီ`,
        },
        // FEE_PENDING — buyer confirm ပြီး၊ admin deposit ပြန်လွှဲ + seller fee confirm လုပ်ရမည်
        FEE_PENDING: {
            title: "⏳ Action လိုသည် — Deposit ပြန်လွှဲ + Fee Pending",
            body: `${buyerName} မှ ${productName} လက်ခံပြီး — Deposit ပြန်လွှဲပြီး Seller fee (၃ ရက်) စောင့်ပါ`,
        },
        // COMPLETED — admin ကိုယ်တိုင် fee confirm လုပ်ခဲ့တာမို့ admin notification မလို
        // (COMPLETED ကို admin ကိုယ်တိုင် trigger လုပ်တာ)
        CANCELLED: {
            title: "Order ပယ်ဖျက်ပြီ",
            body: `${buyerName} မှ ${productName} order ကို ပယ်ဖျက်ပါသည်`,
        },
        RETURN_PENDING: {
            title: "🚩 New Return Request",
            body: `${buyerName} မှ ${productName} အတွက် Return Request တင်ထားပါသည်`,
        },
        RETURN_CLAIMED: {
            title: "💰 New Delivery Claim",
            body: `${sellerName} မှ ${productName} အတွက် Delivery ခ Claim တင်ထားပါသည်`,
        },
        SELLER_REJECTED: {
            title: "🚫 Order Rejected by Seller",
            body: `${sellerName} မှ ${productName} အတွက် Order ကို ပယ်ဖျက်လိုက်ပါသည် (Deposit ပြန်အမ်းရန် လိုအပ်သည်)`,
        },
    };
    if (adminNotifyStatuses[status]) {
        try {
            const adminSnap = await db.collection("users").where("role", "==", "admin").get();
            functions.logger.info(`onOrderStatusChanged: found ${adminSnap.size} admin(s) for ${status}`);
            for (const adminDoc of adminSnap.docs) {
                targets.push({
                    userId: adminDoc.id,
                    title: adminNotifyStatuses[status].title,
                    body: adminNotifyStatuses[status].body,
                    targetRole: "admin",
                });
            }
        }
        catch (e) {
            functions.logger.warn("onOrderStatusChanged: admin query failed", e);
        }
    }
    if (targets.length === 0)
        return;
    await Promise.allSettled(targets.map(async ({ userId, title, body, targetRole }) => {
        var _a, _b;
        // ── 1. Firestore in-app notification (idempotent) ─────────────────
        // Deterministic doc ID prevents duplicate notifications on CF retry
        const notifDocId = `order_${orderId}_${status}_${userId}`;
        try {
            await db.collection("notifications").doc(notifDocId).set({
                userId,
                type: "order",
                targetRole,
                title,
                body,
                orderId,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onOrderStatusChanged: Firestore notif failed for ${userId}`, e);
        }
        // ── 2. FCM push ───────────────────────────────────────────────────
        try {
            const userSnap = await db.collection("users").doc(userId).get();
            const fcmToken = (_b = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.fcmToken) !== null && _b !== void 0 ? _b : "";
            if (!fcmToken) {
                functions.logger.warn(`onOrderStatusChanged: no FCM token for ${userId}`);
                return;
            }
            await sendFcmSafe(fcmToken, userId, {
                notification: { title, body },
                data: { type: "order", orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onOrderStatusChanged: FCM sent to ${userId} (${status})`);
        }
        catch (e) {
            functions.logger.warn(`onOrderStatusChanged: FCM failed for ${userId}`, e);
        }
    }));
});
/* =========================================================
   sendNotification — HTTPS Callable
   Flutter app ကနေ notification_helper.dart မှတဆင့် call လုပ်
   Admin SDK သုံး → Firestore rules bypass + FCM send

   Input: { userId, type, title, body, chatId?, orderId?, senderName? }
========================================================= */
exports.sendNotification = functions
    .region("asia-southeast1")
    .runWith({ enforceAppCheck: false }) // auth guard below is sufficient
    .https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    // ── Auth guard ──────────────────────────────────────────────────────────
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Login required");
    }
    const { userId, type, title, body, chatId, orderId, senderName, targetRole } = data;
    if (!userId || !title || !body) {
        throw new functions.https.HttpsError("invalid-argument", "userId, title, body are required");
    }
    if (chatId) {
        const chatSnap = await db.collection("chats").doc(chatId).get();
        if (!chatSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Chat not found");
        }
        const participants = (_b = (_a = chatSnap.data()) === null || _a === void 0 ? void 0 : _a.participants) !== null && _b !== void 0 ? _b : [];
        if (!participants.includes(context.auth.uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not a participant");
        }
        if (!participants.includes(userId)) {
            throw new functions.https.HttpsError("invalid-argument", "Invalid recipient");
        }
    }
    else {
        const callerSnap = await db.collection("users").doc(context.auth.uid).get();
        if (((_c = callerSnap.data()) === null || _c === void 0 ? void 0 : _c.role) !== "admin") {
            throw new functions.https.HttpsError("permission-denied", "Admins only");
        }
    }
    // ── 1. Write in-app notification to Firestore ───────────────────────────
    const notifData = {
        userId,
        type: type !== null && type !== void 0 ? type : "general",
        title,
        body,
        isRead: false,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    };
    if (chatId) {
        notifData.chatId = chatId;
        notifData.senderId = context.auth.uid;
        notifData.receiverId = userId;
    }
    if (orderId)
        notifData.orderId = orderId;
    if (senderName)
        notifData.senderName = senderName;
    if (targetRole)
        notifData.targetRole = targetRole;
    await db.collection("notifications").add(notifData);
    // ── 2. FCM push to user's device ────────────────────────────────────────
    try {
        const userSnap = await db.collection("users").doc(userId).get();
        const fcmToken = (_e = (_d = userSnap.data()) === null || _d === void 0 ? void 0 : _d.fcmToken) !== null && _e !== void 0 ? _e : "";
        if (fcmToken) {
            const msgData = { type: type !== null && type !== void 0 ? type : "general" };
            if (orderId)
                msgData.orderId = orderId;
            if (chatId)
                msgData.chatId = chatId;
            await sendFcmSafe(fcmToken, userId, {
                notification: { title, body },
                data: msgData,
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`sendNotification: FCM sent to ${userId}`);
        }
        else {
            functions.logger.warn(`sendNotification: no FCM token for ${userId}`);
        }
    }
    catch (fcmErr) {
        // FCM failure is non-fatal — in-app notification already written
        functions.logger.warn(`sendNotification: FCM failed for ${userId}`, fcmErr);
    }
    return { success: true };
});
/* =========================================================
   onNewOrder — Admin Notification on New Deposit
   orders collection မှာ document အသစ် create ဖြစ်သည့်အခါ
   role == 'admin' user အားလုံးကို FCM + in-app notification ပို့
========================================================= */
exports.onNewOrder = functions
    .region("asia-southeast1") // ✅ Fixed: was "us-central1"
    .firestore.document("orders/{orderId}")
    .onCreate(async (snap, context) => {
    var _a, _b;
    const order = snap.data();
    const orderId = context.params.orderId;
    const productName = (_a = order.productName) !== null && _a !== void 0 ? _a : "ပစ္စည်း";
    const buyerName = (_b = order.buyerName) !== null && _b !== void 0 ? _b : "Buyer";
    const title = "🛒 New Deposit လာပါပြီ";
    const body = `${buyerName} မှ ${productName} အတွက် Deposit တင်ထားပါသည်`;
    functions.logger.info(`onNewOrder: new order ${orderId} from ${buyerName}`);
    // ── Find all admin users ────────────────────────────────────────────────
    let adminSnap;
    try {
        adminSnap = await db
            .collection("users")
            .where("role", "==", "admin")
            .get();
    }
    catch (e) {
        functions.logger.error("onNewOrder: failed to query admins", e);
        return;
    }
    if (adminSnap.empty) {
        functions.logger.warn("onNewOrder: no admin users found");
        return;
    }
    // ── Notify each admin ──────────────────────────────────────────────────
    await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
        var _a;
        const adminId = adminDoc.id;
        const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        // In-app notification (Firestore) — idempotent doc ID prevents CF retry duplicates
        try {
            await db.collection("notifications")
                .doc(`new_order_${orderId}_${adminId}`)
                .set({
                userId: adminId,
                type: "new_order",
                targetRole: "admin",
                title,
                body,
                orderId,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onNewOrder: in-app notif failed for admin ${adminId}`, e);
        }
        // FCM push
        if (!fcmToken) {
            functions.logger.warn(`onNewOrder: no FCM token for admin ${adminId}`);
            return;
        }
        try {
            await sendFcmSafe(fcmToken, adminId, {
                notification: { title, body },
                data: { type: "new_order", orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onNewOrder: FCM sent to admin ${adminId}`);
        }
        catch (e) {
            functions.logger.warn(`onNewOrder: FCM failed for admin ${adminId}`, e);
        }
    }));
    functions.logger.info(`onNewOrder: notified ${adminSnap.size} admin(s) for order ${orderId}`);
});
/* =========================================================
   onNewImeiSubmission — Admin Notification on IMEI Verification Request
   imei_registry မှာ document အသစ် create ဖြစ်သည့်အခါ
   role == 'admin' user အားလုံးကို FCM + in-app notification ပို့
========================================================= */
exports.onNewImeiSubmission = functions
    .region("asia-southeast1")
    .firestore.document("imei_registry/{imei}")
    .onCreate(async (snap, context) => {
    var _a, _b;
    const data = snap.data();
    const imei = context.params.imei;
    const sellerName = (_a = data.sellerName) !== null && _a !== void 0 ? _a : "Seller";
    const model = (_b = data.model) !== null && _b !== void 0 ? _b : "ဖုန်း";
    const title = "📋 IMEI Verification တင်လာပါပြီ";
    const body = `${sellerName} မှ ${model} (${imei.substring(0, 8)}****) အတွက် IMEI Verification တောင်းနေပါသည်`;
    functions.logger.info(`onNewImeiSubmission: new IMEI ${imei} from ${sellerName}`);
    let adminSnap;
    try {
        adminSnap = await db.collection("users").where("role", "==", "admin").get();
    }
    catch (e) {
        functions.logger.error("onNewImeiSubmission: failed to query admins", e);
        return;
    }
    if (adminSnap.empty) {
        functions.logger.warn("onNewImeiSubmission: no admin users found");
        return;
    }
    await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
        var _a;
        const adminId = adminDoc.id;
        const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        // In-app notification — idempotent doc ID prevents duplicate on CF retry
        try {
            await db.collection("notifications")
                .doc(`new_imei_${imei}_${adminId}`)
                .set({
                userId: adminId,
                type: "new_imei_submission",
                targetRole: "admin",
                title,
                body,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onNewImeiSubmission: in-app notif failed for admin ${adminId}`, e);
        }
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, adminId, {
                notification: { title, body },
                data: { type: "new_imei_submission" },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onNewImeiSubmission: FCM sent to admin ${adminId}`);
        }
        catch (e) {
            functions.logger.warn(`onNewImeiSubmission: FCM failed for admin ${adminId}`, e);
        }
    }));
    functions.logger.info(`onNewImeiSubmission: notified ${adminSnap.size} admin(s) for IMEI ${imei}`);
});
/* =========================================================
   onDepositReturned
   Trigger: depositReturned field true ဖြစ်သည့်အခါ
   Buyer ဆီ FCM + in-app notification ပို့
========================================================= */
exports.onDepositReturned = functions
    .region("asia-southeast1")
    .firestore.document("orders/{orderId}")
    .onWrite(async (change, context) => {
    var _a, _b, _c, _d, _e;
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    // depositReturned false → true ဖြစ်တဲ့ အချိန်မှသာ trigger
    if (before.depositReturned === true)
        return;
    if (after.depositReturned !== true)
        return;
    const orderId = context.params.orderId;
    const buyerId = (_a = after.buyerId) !== null && _a !== void 0 ? _a : "";
    const productName = (_b = after.productName) !== null && _b !== void 0 ? _b : "ပစ္စည်း";
    const depositAmount = (_c = after.depositAmount) !== null && _c !== void 0 ? _c : 0;
    if (!buyerId)
        return;
    const title = "💰 Deposit ပြန်လွှဲပြီးပါပြီ";
    const body = `${productName} — ${depositAmount.toLocaleString()} MMK ပြန်ရပါပြီ`;
    functions.logger.info(`onDepositReturned: order ${orderId}, buyer ${buyerId}`);
    // ── In-app notification — idempotent doc ID prevents CF retry duplicates ──
    try {
        await db.collection("notifications")
            .doc(`deposit_returned_${orderId}_${buyerId}`)
            .set({
            userId: buyerId,
            type: "order",
            targetRole: "buyer",
            title,
            body,
            orderId,
            isRead: false,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (e) {
        functions.logger.warn(`onDepositReturned: notif write failed for ${buyerId}`, e);
    }
    // ── FCM push ─────────────────────────────────────────────────────────
    try {
        const buyerSnap = await db.collection("users").doc(buyerId).get();
        const fcmToken = (_e = (_d = buyerSnap.data()) === null || _d === void 0 ? void 0 : _d.fcmToken) !== null && _e !== void 0 ? _e : "";
        if (!fcmToken)
            return;
        await sendFcmSafe(fcmToken, buyerId, {
            notification: { title, body },
            data: { type: "order", orderId },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
        functions.logger.info(`onDepositReturned: FCM sent to buyer ${buyerId}`);
    }
    catch (e) {
        functions.logger.warn(`onDepositReturned: FCM failed for ${buyerId}`, e);
    }
});
/* =========================================================
   onFeeProofSubmitted
   Trigger: feeProofUrl field အသစ် set ဖြစ်သည့်အခါ
   Admin အားလုံးကို FCM + in-app notification ပို့
========================================================= */
exports.onFeeProofSubmitted = functions
    .region("asia-southeast1")
    .firestore.document("orders/{orderId}")
    .onWrite(async (change, context) => {
    var _a, _b, _c, _d;
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    const proofBefore = (_a = before.feeProofUrl) !== null && _a !== void 0 ? _a : "";
    const proofAfter = (_b = after.feeProofUrl) !== null && _b !== void 0 ? _b : "";
    // feeProofUrl အသစ် set ဖြစ်တဲ့ အချိန်မှသာ trigger
    if (proofBefore === proofAfter || proofAfter === "")
        return;
    if (after.status !== "FEE_PENDING")
        return;
    const orderId = context.params.orderId;
    const productName = (_c = after.productName) !== null && _c !== void 0 ? _c : "ပစ္စည်း";
    const sellerName = (_d = after.sellerName) !== null && _d !== void 0 ? _d : "Seller";
    const title = "💰 Service Charge လွှဲပြီးကြောင်း တင်ပြီး";
    const body = `${sellerName} မှ ${productName} — စစ်ဆေးပြီး confirm လုပ်ပေးပါ`;
    functions.logger.info(`onFeeProofSubmitted: order ${orderId}`);
    let adminSnap;
    try {
        adminSnap = await db.collection("users").where("role", "==", "admin").get();
    }
    catch (e) {
        functions.logger.error("onFeeProofSubmitted: admin query failed", e);
        return;
    }
    await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
        var _a;
        const adminId = adminDoc.id;
        const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        // In-app notification — idempotent doc ID prevents CF retry duplicates
        try {
            await db.collection("notifications")
                .doc(`fee_proof_${orderId}_${adminId}`)
                .set({
                userId: adminId,
                type: "order",
                targetRole: "admin",
                title,
                body,
                orderId,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onFeeProofSubmitted: notif write failed for ${adminId}`, e);
        }
        // FCM push
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, adminId, {
                notification: { title, body },
                data: { type: "order", orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onFeeProofSubmitted: FCM sent to admin ${adminId}`);
        }
        catch (e) {
            functions.logger.warn(`onFeeProofSubmitted: FCM failed for ${adminId}`, e);
        }
    }));
});
/* =========================================================
   onUserRoleChanged — Admin Custom Claim Sync
   users/{userId} document မှာ role field ပြောင်းတိုင်း
   Firebase Auth custom claim ကို sync လုပ်သည်။
   Storage rules မှာ request.auth.token.role == "admin" သုံးနိုင်ရန်။
========================================================= */
exports.onUserRoleChanged = functions
    .region("asia-southeast1")
    .firestore.document("users/{userId}")
    .onWrite(async (change, context) => {
    var _a, _b;
    const after = change.after.data();
    const before = change.before.data();
    if (!after)
        return;
    if ((before === null || before === void 0 ? void 0 : before.role) === after.role)
        return;
    const userId = context.params.userId;
    const role = (_a = after.role) !== null && _a !== void 0 ? _a : "user";
    try {
        const userRecord = await (0, auth_1.getAuth)().getUser(userId);
        const existing = (_b = userRecord.customClaims) !== null && _b !== void 0 ? _b : {};
        await (0, auth_1.getAuth)().setCustomUserClaims(userId, Object.assign(Object.assign({}, existing), { role }));
        functions.logger.info(`Custom claim set: ${userId} → role=${role}`);
    }
    catch (e) {
        functions.logger.error(`Custom claim failed for ${userId}`, e);
    }
});
/* =========================================================
   onNewModelRequest — Admin Notification on New Model Request
   model_requests collection မှာ document အသစ် create ဖြစ်သည့်အခါ
   role == 'admin' user အားလုံးကို FCM + in-app notification ပို့
========================================================= */
exports.onNewModelRequest = functions
    .region("asia-southeast1")
    .firestore.document("model_requests/{requestId}")
    .onCreate(async (snap, context) => {
    var _a, _b, _c;
    const data = snap.data();
    const requestId = context.params.requestId;
    const sellerName = (_a = data.sellerName) !== null && _a !== void 0 ? _a : "Seller";
    const brand = (_b = data.brand) !== null && _b !== void 0 ? _b : "";
    const model = (_c = data.model) !== null && _c !== void 0 ? _c : "";
    const title = "📱 Model Request အသစ်";
    const body = `${sellerName} မှ ${brand} ${model} တောင်းဆိုသည်`;
    functions.logger.info(`onNewModelRequest: ${requestId}`);
    let adminSnap;
    try {
        adminSnap = await db.collection("users").where("role", "==", "admin").get();
    }
    catch (e) {
        functions.logger.error("onNewModelRequest: admin query failed", e);
        return;
    }
    if (adminSnap.empty)
        return;
    await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
        var _a;
        const adminId = adminDoc.id;
        const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        try {
            // ✅ Deterministic doc ID — idempotent against CF at-least-once retries
            await db.collection("notifications")
                .doc(`model_request_${requestId}_${adminId}`)
                .set({
                userId: adminId,
                type: "model_request",
                targetRole: "admin",
                title,
                body,
                requestId,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onNewModelRequest: notif failed for ${adminId}`, e);
        }
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, adminId, {
                notification: { title, body },
                data: { type: "model_request" },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onNewModelRequest: FCM sent to admin ${adminId}`);
        }
        catch (e) {
            functions.logger.warn(`onNewModelRequest: FCM failed for ${adminId}`, e);
        }
    }));
});
/* =========================================================
   onModelRequestStatusChanged — Seller Notification on Approve/Reject
   model_requests document status APPROVED/REJECTED ဖြစ်သည့်အခါ
   seller ဆီ FCM + in-app notification ပို့
========================================================= */
exports.onModelRequestStatusChanged = functions
    .region("asia-southeast1")
    .firestore.document("model_requests/{requestId}")
    .onWrite(async (change, context) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    if (before.status === after.status)
        return;
    const status = (_a = after.status) !== null && _a !== void 0 ? _a : "";
    const sellerId = (_b = after.sellerId) !== null && _b !== void 0 ? _b : "";
    const brand = (_c = after.brand) !== null && _c !== void 0 ? _c : "";
    const model = (_d = after.model) !== null && _d !== void 0 ? _d : "";
    const adminNote = (_e = after.adminNote) !== null && _e !== void 0 ? _e : "";
    if (!sellerId)
        return;
    if (status !== "APPROVED" && status !== "REJECTED")
        return;
    const approved = status === "APPROVED";
    const title = approved ? "✅ Model Request Approved" : "❌ Model Request Rejected";
    const body = approved
        ? `${brand} ${model} — ယခု Product တင်နိုင်ပြီ`
        : `${brand} ${model} — ${adminNote.trim() || "Admin မှ ငြင်းပယ်သည်"}`;
    functions.logger.info(`onModelRequestStatusChanged: ${context.params.requestId} → ${status}`);
    try {
        await db.collection("notifications").add({
            userId: sellerId,
            type: "model_request",
            targetRole: "seller",
            title,
            body,
            isRead: false,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    catch (e) {
        functions.logger.warn(`onModelRequestStatusChanged: notif write failed`, e);
    }
    try {
        const sellerSnap = await db.collection("users").doc(sellerId).get();
        const fcmToken = (_g = (_f = sellerSnap.data()) === null || _f === void 0 ? void 0 : _f.fcmToken) !== null && _g !== void 0 ? _g : "";
        if (!fcmToken)
            return;
        await sendFcmSafe(fcmToken, sellerId, {
            notification: { title, body },
            data: { type: "model_request" },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
        functions.logger.info(`onModelRequestStatusChanged: FCM sent to seller ${sellerId}`);
    }
    catch (e) {
        functions.logger.warn(`onModelRequestStatusChanged: FCM failed for ${sellerId}`, e);
    }
});
/* =========================================================
   onUserVerificationDocUploaded — Admin Notif on License Upload
   Seller က verificationDocUrl တင်လိုက်သည့်အခါ
   Admin အားလုံးဆီ FCM + In-app notif ပို့ပေးသည်။
========================================================= */
exports.onUserVerificationDocUploaded = functions
    .region("asia-southeast1")
    .firestore.document("users/{userId}")
    .onUpdate(async (change, context) => {
    var _a, _b, _c;
    const before = change.before.data();
    const after = change.after.data();
    if (!after || !before)
        return;
    // Only fire when verificationDocUrl was empty/null and now has a value
    const docBefore = (_a = before.verificationDocUrl) !== null && _a !== void 0 ? _a : "";
    const docAfter = (_b = after.verificationDocUrl) !== null && _b !== void 0 ? _b : "";
    if (docBefore === "" && docAfter !== "") {
        const sellerName = (_c = after.name) !== null && _c !== void 0 ? _c : "Seller";
        const sellerId = context.params.userId;
        const title = "📋 Verification Request အသစ်";
        const body = `${sellerName} မှ ဆိုင်လိုင်စင် တင်ပြထားပါသည်။ စစ်ဆေးပေးပါရန်။`;
        functions.logger.info(`onUserVerificationDocUploaded: new request from ${sellerId}`);
        let adminSnap;
        try {
            adminSnap = await db.collection("users").where("role", "==", "admin").get();
        }
        catch (e) {
            functions.logger.error("onUserVerificationDocUploaded: admin query failed", e);
            return;
        }
        if (adminSnap.empty)
            return;
        await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
            var _a;
            const adminId = adminDoc.id;
            const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
            // Firestore in-app notification (idempotent)
            try {
                await db.collection("notifications")
                    .doc(`verify_request_${sellerId}_${adminId}`)
                    .set({
                    userId: adminId,
                    type: "verify_request",
                    targetRole: "admin",
                    title,
                    body,
                    sellerId,
                    isRead: false,
                    createdAt: firestore_1.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            catch (e) {
                functions.logger.warn(`onUserVerificationDocUploaded: in-app notif failed`, e);
            }
            // FCM push
            if (!fcmToken)
                return;
            try {
                await sendFcmSafe(fcmToken, adminId, {
                    notification: { title, body },
                    data: { type: "verify_request", sellerId },
                    android: { priority: "high" },
                    apns: { payload: { aps: { sound: "default", badge: 1 } } },
                });
                functions.logger.info(`onUserVerificationDocUploaded: FCM sent to admin ${adminId}`);
            }
            catch (e) {
                functions.logger.warn(`onUserVerificationDocUploaded: FCM failed`, e);
            }
        }));
    }
});
/* =========================================================
   onNewChatMessage — Chat Notification
   chats/{chatId}/messages/{messageId} create ဖြစ်သည့်အခါ
   recipient ဆီ FCM + in-app notification ပို့
========================================================= */
exports.onNewChatMessage = functions
    .region("asia-southeast1")
    .firestore.document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m;
    const msg = snap.data();
    if (!msg)
        return;
    const chatId = context.params.chatId;
    const senderId = (_a = msg.senderId) !== null && _a !== void 0 ? _a : "";
    if (!senderId)
        return;
    const chatSnap = await db.collection("chats").doc(chatId).get();
    if (!chatSnap.exists)
        return;
    const participants = (_c = (_b = chatSnap.data()) === null || _b === void 0 ? void 0 : _b.participants) !== null && _c !== void 0 ? _c : [];
    const recipientId = participants.find((p) => p !== senderId);
    if (!recipientId)
        return;
    // ✅ recipientSnap ကို ဦးစွာ declare — အောက်မှာ နှစ်ကြိမ်သုံးနိုင်
    const senderSnap = await db.collection("users").doc(senderId).get();
    const recipientSnap = await db.collection("users").doc(recipientId).get();
    const senderName = (_e = (_d = senderSnap.data()) === null || _d === void 0 ? void 0 : _d.name) !== null && _e !== void 0 ? _e : "User";
    const fcmToken = (_g = (_f = recipientSnap.data()) === null || _f === void 0 ? void 0 : _f.fcmToken) !== null && _g !== void 0 ? _g : "";
    const blockedUsers = (_j = (_h = recipientSnap.data()) === null || _h === void 0 ? void 0 : _h.blockedUsers) !== null && _j !== void 0 ? _j : [];
    if (Array.isArray(blockedUsers) && blockedUsers.includes(senderId)) {
        functions.logger.info(`onNewChatMessage: blocked, skip`);
        return;
    }
    // Use recipient's actual role so the in-app notification routes correctly
    const recipientRole = (_l = (_k = recipientSnap.data()) === null || _k === void 0 ? void 0 : _k.role) !== null && _l !== void 0 ? _l : "user";
    const body = msg.imageUrl ? "📷 Photo" : ((_m = msg.text) !== null && _m !== void 0 ? _m : "");
    // In-app notification
    try {
        await db.collection("notifications").add({
            userId: recipientId,
            type: "chat",
            targetRole: recipientRole,
            title: senderName,
            body,
            chatId,
            senderId,
            receiverId: recipientId,
            isRead: false,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    catch (e) {
        functions.logger.warn(`onNewChatMessage: notif write failed`, e);
    }
    try {
        if (!fcmToken)
            return;
        await sendFcmSafe(fcmToken, recipientId, {
            notification: { title: senderName, body },
            data: { type: "chat", chatId, senderId },
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
        functions.logger.info(`onNewChatMessage: FCM sent to ${recipientId}`);
    }
    catch (e) {
        functions.logger.warn(`onNewChatMessage: FCM failed for ${recipientId}`, e);
    }
});
exports.onNewReport = functions
    .region("asia-southeast1")
    .firestore.document("reports/{reportId}")
    .onCreate(async (snap) => {
    var _a, _b, _c;
    const report = snap.data();
    if (!report)
        return;
    const reportedBy = (_a = report.reportedBy) !== null && _a !== void 0 ? _a : "";
    const reporterSnap = await db.collection("users").doc(reportedBy).get();
    const reporterName = (_c = (_b = reporterSnap.data()) === null || _b === void 0 ? void 0 : _b.name) !== null && _c !== void 0 ? _c : "User";
    const title = "🚩 User Report တင်ပြီး";
    const body = `${reporterName} မှ report တင်ပါသည် — စစ်ဆေးပေးပါ`;
    const adminSnap = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();
    await Promise.allSettled(adminSnap.docs.map(async (adminDoc) => {
        var _a;
        const adminId = adminDoc.id;
        const fcmToken = (_a = adminDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        // Firestore in-app notification
        try {
            await db.collection("notifications").add({
                userId: adminId,
                type: "report",
                targetRole: "admin",
                title,
                body,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        catch (e) {
            functions.logger.warn(`onNewReport: notif write failed for ${adminId}`, e);
        }
        // FCM push
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, adminId, {
                notification: { title, body },
                data: { type: "report" },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onNewReport: FCM sent to admin ${adminId}`);
        }
        catch (e) {
            functions.logger.warn(`onNewReport: FCM failed for ${adminId}`, e);
        }
    }));
});
/* =========================================================
   autoFreezePendingFees — Daily Scheduled Job
   feeDeadline ကျော်ပြီး pendingFee > 0 ရှိသော seller
   အားလုံးကို listingsFrozen: true set လုပ်ပြီး product အားလုံးကို deactivate လုပ်သည်။
   (UTC 02:00 = Myanmar Time 08:30)
   onOrderStatusChanged (COMPLETED) က listingsFrozen: false ပြန်ဖျက်မည်
========================================================= */
exports.autoFreezePendingFees = functions
    .region("asia-southeast1")
    .pubsub.schedule("0 2 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    const now = firestore_1.Timestamp.now();
    // Firestore: range filter ကို field တစ်ခုကိုသာ ခွင့်ပြုသောကြောင့်
    // feeDeadline < now ဖြင့် query ၊ pendingFee > 0 ကို in-code filter လုပ်
    let overdueSnap;
    try {
        overdueSnap = await db
            .collection("users")
            .where("feeDeadline", "<", now)
            .get();
    }
    catch (e) {
        functions.logger.error("autoFreezePendingFees: query failed", e);
        return;
    }
    const overdueSellers = overdueSnap.docs.filter((doc) => {
        var _a;
        const fee = (_a = doc.data().pendingFee) !== null && _a !== void 0 ? _a : 0;
        return fee > 0;
    });
    if (overdueSellers.length === 0) {
        functions.logger.info("autoFreezePendingFees: no overdue sellers");
        return;
    }
    functions.logger.info(`autoFreezePendingFees: found ${overdueSellers.length} overdue sellers`);
    for (const sellerDoc of overdueSellers) {
        const sellerId = sellerDoc.id;
        try {
            const batch = db.batch();
            // 1. Freeze user
            batch.update(sellerDoc.ref, {
                listingsFrozen: true,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
            // 2. Deactivate all their products
            const productsSnap = await db
                .collection("products")
                .where("sellerId", "==", sellerId)
                .where("active", "==", true) // Only deactivate currently active ones
                .get();
            for (const productDoc of productsSnap.docs) {
                batch.update(productDoc.ref, {
                    active: false,
                    deactivatedByFeeFreeze: true,
                    updatedAt: firestore_1.FieldValue.serverTimestamp(),
                });
            }
            await batch.commit();
            functions.logger.info(`autoFreezePendingFees: froze seller ${sellerId} and ${productsSnap.size} products`);
        }
        catch (e) {
            functions.logger.error(`autoFreezePendingFees: failed for seller ${sellerId}`, e);
        }
    }
    // ── Notify each frozen seller ─────────────────────────────────────────
    const title = "⚠️ အကောင့် ယာယီ ပိတ်သိမ်းခြင်း";
    const body = "Service charge နောက်ကျနေသဖြင့် listing များ ပိတ်သိမ်းလိုက်သည်။ အမြန် ပေးချေပါ။";
    await Promise.allSettled(overdueSellers.map(async (sellerDoc) => {
        var _a;
        const sellerId = sellerDoc.id;
        const fcmToken = (_a = sellerDoc.data().fcmToken) !== null && _a !== void 0 ? _a : "";
        // In-app notification — idempotent key (date + sellerId)
        const today = new Date().toISOString().slice(0, 10); // "2025-06-24"
        const notifId = `fee_freeze_${sellerId}_${today}`;
        try {
            await db.collection("notifications").doc(notifId).set({
                userId: sellerId,
                type: "fee_freeze",
                targetRole: "seller",
                title,
                body,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`autoFreezePendingFees: notif write failed for ${sellerId}`, e);
        }
        // FCM push
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, sellerId, {
                notification: { title, body },
                data: { type: "fee_freeze" },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
            });
            functions.logger.info(`autoFreezePendingFees: FCM sent to seller ${sellerId}`);
        }
        catch (e) {
            functions.logger.warn(`autoFreezePendingFees: FCM failed for ${sellerId}`, e);
        }
    }));
});
/* =========================================================
   onProductImeiRejected — Firestore Trigger
   products/{productId} မှာ imeiStatus field REJECTED ဖြစ်သွားတဲ့အခါ
   seller ကို product_rejected notification ပို့သည်
   (Admin SDK သုံး → auth issue မရှိ, client call မလို)
========================================================= */
exports.onProductImeiRejected = functions
    .region("asia-southeast1")
    .firestore.document("products/{productId}")
    .onUpdate(async (change) => {
    var _a, _b, _c, _d, _e;
    const before = change.before.data();
    const after = change.after.data();
    // Only fire when imeiStatus just changed TO "REJECTED"
    if (before.imeiStatus === "REJECTED" || after.imeiStatus !== "REJECTED")
        return;
    const sellerId = (_a = after.sellerId) !== null && _a !== void 0 ? _a : "";
    if (!sellerId) {
        functions.logger.warn("onProductImeiRejected: no sellerId on product");
        return;
    }
    const brand = ((_b = after.brand) !== null && _b !== void 0 ? _b : "").toString();
    const model = ((_c = after.model) !== null && _c !== void 0 ? _c : "").toString();
    const displayTitle = model.toLowerCase().startsWith(brand.toLowerCase())
        ? model
        : `${brand} ${model}`;
    const title = "⚠️ ပစ္စည်းတင် Reject ခံရသည်";
    const body = `${displayTitle} — အချက်အလက်ကိုက်ညီမှု မရှိ၍ ဖယ်ရှားလိုက်သည်။`
        + " အချက်အလက် မှန်ကန်စွာ ပြင်ဆင်ပြီး ပြန်တင်ပါ။"
        + " ထပ်မံဖြစ်ပါက အကောင့်ပိတ်သိမ်းခံရမည်။";
    // Write in-app notification (idempotent)
    const productId = change.after.id;
    const notifId = `product_rejected_${productId}`;
    try {
        await db.collection("notifications").doc(notifId).set({
            userId: sellerId,
            type: "product_rejected",
            targetRole: "seller",
            title,
            body,
            isRead: false,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        functions.logger.info(`onProductImeiRejected: notification written for seller ${sellerId}`);
    }
    catch (e) {
        functions.logger.error("onProductImeiRejected: notification write failed", e);
    }
    // FCM push
    try {
        const userSnap = await db.collection("users").doc(sellerId).get();
        const fcmToken = (_e = (_d = userSnap.data()) === null || _d === void 0 ? void 0 : _d.fcmToken) !== null && _e !== void 0 ? _e : "";
        if (fcmToken) {
            await sendFcmSafe(fcmToken, sellerId, {
                notification: { title, body },
                data: { type: "product_rejected" },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
            });
            functions.logger.info(`onProductImeiRejected: FCM sent to seller ${sellerId}`);
        }
    }
    catch (e) {
        functions.logger.warn("onProductImeiRejected: FCM failed", e);
    }
});
/* =========================================================
   onReviewCreated — Seller Rating Aggregation
   reviews/{reviewId} create ဖြစ်သည့်အခါ
   seller user doc မှာ avgRating + reviewCount ကို
   transaction ဖြင့် atomically update လုပ်သည်
   (Admin SDK သုံးသောကြောင့် Firestore rules bypass)
========================================================= */
/* =========================================================
   runImeiCheck — HTTPS Callable (Admin only)
   imei.org API ကို call ပြီး result ကို Firestore သိမ်းသည်

   Input:  { imei, productId, brand, deviceType }
   Output: { success, parsed, raw }
========================================================= */
// ── Service name → imei.org service name mapping ─────────────────────────────
function _imeiServiceName(brand, deviceType) {
    const b = brand.toLowerCase().trim();
    const dt = deviceType.toLowerCase().trim();
    if (dt === "iphone" || dt === "ipad")
        return "Apple Carrier Check";
    if (b === "samsung")
        return "Samsung [info] [Pro - 2]";
    if (b === "xiaomi" || b === "redmi" || b === "poco")
        return "Xiaomi Mi Lock [Info]";
    if (b === "oppo")
        return "Oppo [Info]";
    if (b === "vivo")
        return "Vivo [info]";
    if (b === "infinix" || b === "tecno" || b === "itel")
        return "Itel | Tecno [Info]";
    if (b === "huawei")
        return "Huawei Pro [info]";
    if (b === "honor")
        return "Honor [Info]";
    if (b === "google" || b === "pixel")
        return "Google Pixel [Info]";
    if (b === "asus")
        return "Asus Pro [Info]";
    if (b === "lenovo")
        return "Lenovo Pro [Info]";
    if (b === "motorola")
        return "Motorola [info]";
    if (b === "nokia")
        return "Nokia [Info]";
    if (b === "realme")
        return "Realme";
    if (b === "oneplus")
        return "OnePlus";
    if (b === "sony")
        return "Sony";
    if (b === "nothing")
        return "Nothing";
    return brand;
}
// ── Helper: Extract flat key-value dict from raw imei.org response ────────────
function _extractRawDict(obj) {
    var _a, _b;
    if (!obj || typeof obj !== "object")
        return {};
    const rawObj = obj;
    const dict = {};
    const parseStr = (str) => {
        const lines = str.replace(/<br\s*\/?>/gi, "\n").split(/\r?\n/);
        for (const line of lines) {
            const idx = line.indexOf(":");
            if (idx > 0) {
                const k = line.substring(0, idx).trim();
                const v = line.substring(idx + 1).trim();
                if (k && v)
                    dict[k] = v;
            }
        }
    };
    const resField = (_b = (_a = rawObj["result"]) !== null && _a !== void 0 ? _a : rawObj["Response"]) !== null && _b !== void 0 ? _b : rawObj["response"];
    if (resField) {
        if (typeof resField === "object" && resField !== null) {
            if (Array.isArray(resField)) {
                for (const item of resField) {
                    if (typeof item === "string")
                        parseStr(item);
                    else if (typeof item === "object" && item !== null) {
                        for (const [k, v] of Object.entries(item)) {
                            if (v != null)
                                dict[k] = String(v).trim();
                        }
                    }
                }
            }
            else {
                for (const [k, v] of Object.entries(resField)) {
                    if (v != null && typeof v !== "object")
                        dict[k] = String(v).trim();
                    else if (typeof v === "string")
                        parseStr(v);
                }
            }
        }
        else if (typeof resField === "string") {
            parseStr(resField);
        }
    }
    for (const [k, v] of Object.entries(rawObj)) {
        if (k !== "result" && k !== "response" && k !== "Response" && v != null && typeof v !== "object") {
            dict[k] = String(v).trim();
        }
    }
    return dict;
}
// ── Parse imei.org result into structured data ────────────────────────────────
function _parseImeiResult(raw, deviceType) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13;
    const dt = deviceType.toLowerCase();
    const isApple = dt === "iphone" || dt === "ipad";
    const modelField = ((_b = (_a = raw["Model"]) !== null && _a !== void 0 ? _a : raw["Model Desc"]) !== null && _b !== void 0 ? _b : "").toString();
    let modelName = null;
    let storage = ((_d = (_c = raw["Storage"]) !== null && _c !== void 0 ? _c : raw["Capacity"]) !== null && _d !== void 0 ? _d : "").toString() || null;
    let color = ((_e = raw["Color"]) !== null && _e !== void 0 ? _e : "").toString() || null;
    let modelNumber = ((_g = (_f = raw["Model Number"]) !== null && _f !== void 0 ? _f : raw["Model No"]) !== null && _g !== void 0 ? _g : "").toString() || null;
    if (isApple && modelField) {
        if (!storage) {
            const storageMatch = modelField.match(/\b(\d+(?:GB|TB))\b/i);
            if (storageMatch)
                storage = storageMatch[1].toUpperCase();
        }
        if (!color) {
            const appleColors = [
                "BLACK", "WHITE", "SILVER", "GOLD", "ROSE GOLD", "SPACE GRAY",
                "MIDNIGHT", "STARLIGHT", "BLUE", "GREEN", "RED", "PURPLE",
                "YELLOW", "PINK", "ORANGE", "NATURAL TITANIUM", "BLACK TITANIUM",
                "WHITE TITANIUM", "DESERT TITANIUM",
            ];
            for (const c of appleColors) {
                if (modelField.toUpperCase().includes(c)) {
                    color = c.charAt(0).toUpperCase() + c.slice(1).toLowerCase();
                    break;
                }
            }
        }
        const storageIndex = storage ? modelField.indexOf(storage) : -1;
        const beforeStorage = storageIndex !== -1
            ? modelField.substring(0, storageIndex).trim()
            : modelField.split("[")[0].trim();
        modelName = beforeStorage
            .replace(/^IPHONE\s*/i, "iPhone ")
            .replace(/^IPAD\s*/i, "iPad ")
            .trim();
        if (!modelNumber) {
            const bracketMatch = modelField.match(/\[([A-Z]\d{4}[A-Z]?)\]/);
            if (bracketMatch)
                modelNumber = bracketMatch[1];
        }
    }
    else {
        modelName = ((_j = (_h = raw["Model Desc"]) !== null && _h !== void 0 ? _h : raw["Model"]) !== null && _j !== void 0 ? _j : "").toString() || null;
        if (!color) {
            const fullName = ((_k = raw["Full Name"]) !== null && _k !== void 0 ? _k : "").toString();
            const androidColors = [
                "BLACK", "WHITE", "SILVER", "GOLD", "BLUE", "GREEN", "RED",
                "PURPLE", "GRAY", "GREY", "PINK", "ORANGE", "YELLOW", "VIOLET",
                "CREAM", "LAVENDER", "GRAPHITE", "PHANTOM", "MIDNIGHT BLACK",
            ];
            for (const c of androidColors) {
                if (fullName.toUpperCase().includes(c)) {
                    color = c.charAt(0).toUpperCase() + c.slice(1).toLowerCase();
                    break;
                }
            }
        }
    }
    // Keys that are explicitly mapped or internal metadata
    const knownRawKeys = new Set([
        "Serial Number", "Serial",
        "IMEI2", "IMEI 2",
        "Manufacturer", "Brand",
        "Full Name", "Device Name",
        "Model Number", "Model No",
        "Model Desc", "Model",
        "Production Date",
        "Date of Purchase", "Purchase Date",
        "Warranty Until", "Warranty Date",
        "Warranty Status",
        "Carrier",
        "Country", "Purchase Country",
        "Blacklist Status", "Blacklisted By",
        "FMI", "FMI Status", "iCloud", "iCloud Status", "Simlock", "SIM Lock", "KnoxGuard",
        "Activated", "Storage", "Capacity", "Color",
        "id", "status", "Status", "service_id", "input", "order_id", "orderId", "code", "message"
    ]);
    const extras = {};
    for (const [k, v] of Object.entries(raw)) {
        if (!knownRawKeys.has(k) && v != null && String(v).trim() !== "") {
            extras[k] = String(v);
        }
    }
    return Object.assign({ modelName,
        modelNumber, fullName: ((_m = (_l = raw["Full Name"]) !== null && _l !== void 0 ? _l : raw["Device Name"]) !== null && _m !== void 0 ? _m : "").toString() || null, storage,
        color, manufacturer: ((_p = (_o = raw["Manufacturer"]) !== null && _o !== void 0 ? _o : raw["Brand"]) !== null && _p !== void 0 ? _p : "").toString() || null, serialNumber: ((_r = (_q = raw["Serial Number"]) !== null && _q !== void 0 ? _q : raw["Serial"]) !== null && _r !== void 0 ? _r : "").toString() || null, imei2: ((_t = (_s = raw["IMEI2"]) !== null && _s !== void 0 ? _s : raw["IMEI 2"]) !== null && _t !== void 0 ? _t : "").toString() || null, productionDate: ((_u = raw["Production Date"]) !== null && _u !== void 0 ? _u : "").toString() || null, purchaseDate: ((_w = (_v = raw["Date of Purchase"]) !== null && _v !== void 0 ? _v : raw["Purchase Date"]) !== null && _w !== void 0 ? _w : "").toString() || null, warrantyUntil: ((_y = (_x = raw["Warranty Until"]) !== null && _x !== void 0 ? _x : raw["Warranty Date"]) !== null && _y !== void 0 ? _y : "").toString() || null, warrantyStatus: ((_z = raw["Warranty Status"]) !== null && _z !== void 0 ? _z : "").toString() || null, fmi: ((_1 = (_0 = raw["FMI"]) !== null && _0 !== void 0 ? _0 : raw["FMI Status"]) !== null && _1 !== void 0 ? _1 : "").toString() || null, icloud: ((_3 = (_2 = raw["iCloud"]) !== null && _2 !== void 0 ? _2 : raw["iCloud Status"]) !== null && _3 !== void 0 ? _3 : "").toString() || null, simlock: ((_5 = (_4 = raw["Simlock"]) !== null && _4 !== void 0 ? _4 : raw["SIM Lock"]) !== null && _5 !== void 0 ? _5 : "").toString() || null, blacklist: ((_7 = (_6 = raw["Blacklist Status"]) !== null && _6 !== void 0 ? _6 : raw["Blacklist"]) !== null && _7 !== void 0 ? _7 : "").toString() || null, blacklistedBy: ((_8 = raw["Blacklisted By"]) !== null && _8 !== void 0 ? _8 : "").toString() || null, knoxGuard: ((_9 = raw["KnoxGuard"]) !== null && _9 !== void 0 ? _9 : "").toString() || null, carrier: ((_10 = raw["Carrier"]) !== null && _10 !== void 0 ? _10 : "").toString() || null, country: ((_12 = (_11 = raw["Country"]) !== null && _11 !== void 0 ? _11 : raw["Purchase Country"]) !== null && _12 !== void 0 ? _12 : "").toString() || null, activated: ((_13 = raw["Activated"]) !== null && _13 !== void 0 ? _13 : "").toString() || null }, extras);
}
exports.runImeiCheck = functions
    .region("asia-southeast1")
    .runWith({ timeoutSeconds: 300, memory: "256MB" })
    .https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t;
    // ── Auth guard — admin only ───────────────────────────────────────────────
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Login required");
    }
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    if (((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Admins only");
    }
    const { imei, productId, brand, deviceType } = data;
    if (!imei || !productId) {
        throw new functions.https.HttpsError("invalid-argument", "imei and productId are required");
    }
    // ── API key from environment variable ───────────────────────────────────
    const apiKey = (_b = process.env.IMEI_API_KEY) !== null && _b !== void 0 ? _b : "";
    if (!apiKey) {
        throw new functions.https.HttpsError("internal", "IMEI_API_KEY not set. Add to functions/.env and redeploy.");
    }
    const targetBrand = (brand || deviceType || "").trim();
    let serviceName = _imeiServiceName(targetBrand, deviceType || "");
    let serviceId = null;
    let raw = {};
    let allAvailableServices = [];
    try {
        // ── Step 1: Get service list → find service_id ───────────────────────────
        try {
            const svcRes = await fetch(`https://api-client.imei.org/api/services?apikey=${apiKey}`);
            const svcJson = await svcRes.json();
            if (svcJson.status === 1 && ((_c = svcJson.response) === null || _c === void 0 ? void 0 : _c.services)) {
                const allServices = svcJson.response.services;
                allAvailableServices = allServices.map(s => s.name);
                const targetClean = serviceName.toLowerCase().replace(/\[.*?\]/g, "").trim();
                const brandClean = targetBrand.toLowerCase().trim();
                // 1. Exact match
                const exact = allServices.find(s => s.name.toLowerCase() === serviceName.toLowerCase());
                if (exact) {
                    serviceId = exact.id;
                    serviceName = exact.name;
                }
                else {
                    // 2. Contains match
                    let partial = allServices.filter(s => (targetClean.length > 0 && s.name.toLowerCase().includes(targetClean)) ||
                        (brandClean.length > 0 && s.name.toLowerCase().includes(brandClean)));
                    if (partial.length > 0) {
                        const cheapest = partial.reduce((a, b) => a.price < b.price ? a : b);
                        serviceId = cheapest.id;
                        serviceName = cheapest.name;
                    }
                }
            }
            else {
                functions.logger.warn("runImeiCheck: services response invalid", svcJson);
            }
        }
        catch (e) {
            functions.logger.warn("runImeiCheck: service list fetch failed", e);
        }
        if (serviceId === null) {
            const topServices = allAvailableServices.slice(0, 15).join(", ");
            throw new functions.https.HttpsError("not-found", `Service "${targetBrand}" ကို သင်၏ API key တွင် ရှာမတွေ့ပါ။ ရနိုင်သော service အချို့: ${topServices || "None"}`);
        }
        const cleanImei = imei.replace(/\D/g, "").trim();
        if (cleanImei.length < 14 || cleanImei.length > 16) {
            throw new functions.https.HttpsError("invalid-argument", `IMEI နံပါတ် မှားယွင်းနေပါသည်။ (${imei}) — IMEI သည် ၁၅ လုံး ရှိရပါမည်။`);
        }
        functions.logger.info(`runImeiCheck: imei=${cleanImei} brand=${targetBrand} serviceId=${serviceId} serviceName=${serviceName}`);
        // ── Step 2: Place order & get result ─────────────────────────────────────
        let orderJson = null;
        try {
            const orderRes = await fetch(`https://api-client.imei.org/api/submit?apikey=${apiKey}&service_id=${serviceId}&input=${cleanImei}`);
            orderJson = await orderRes.json();
            functions.logger.info("runImeiCheck: submit response", JSON.stringify(orderJson).slice(0, 600));
        }
        catch (e) {
            functions.logger.error("runImeiCheck: submit fetch error", e);
            throw new functions.https.HttpsError("internal", `imei.org Submit Connection Error: ${e}`);
        }
        if (!orderJson || orderJson.status !== 1 || !orderJson.response) {
            let errMsg = (_d = orderJson === null || orderJson === void 0 ? void 0 : orderJson.message) !== null && _d !== void 0 ? _d : orderJson === null || orderJson === void 0 ? void 0 : orderJson.error;
            if (!errMsg) {
                if (typeof (orderJson === null || orderJson === void 0 ? void 0 : orderJson.response) === "string") {
                    errMsg = orderJson.response;
                }
                else if ((orderJson === null || orderJson === void 0 ? void 0 : orderJson.response) && typeof orderJson.response === "object") {
                    const resObj = orderJson.response;
                    errMsg = ((_g = (_f = (_e = resObj["message"]) !== null && _e !== void 0 ? _e : resObj["error"]) !== null && _f !== void 0 ? _f : resObj["reason"]) !== null && _g !== void 0 ? _g : JSON.stringify(resObj)).toString();
                }
                else {
                    errMsg = "Order submit failed (imei.org တွင် credit မရှိခြင်း သို့မဟုတ် IMEI မှားယွင်းနေခြင်း ဖြစ်နိုင်ပါသည်)";
                }
            }
            throw new functions.https.HttpsError("internal", `imei.org API Error: ${errMsg}`);
        }
        const respObj = orderJson.response;
        // Check if result is ALREADY complete in submit response
        const initDict = _extractRawDict(respObj);
        const initStatus = ((_j = (_h = initDict["Status"]) !== null && _h !== void 0 ? _h : initDict["status"]) !== null && _j !== void 0 ? _j : "").toString().toUpperCase();
        const hasDeviceSpecs = !!(initDict["Model"] ||
            initDict["Full Name"] ||
            initDict["Model Desc"] ||
            initDict["Manufacturer"] ||
            initDict["Model Number"] ||
            initDict["Serial"] ||
            initDict["Serial Number"]);
        if (hasDeviceSpecs || initStatus === "DONE" || initStatus === "COMPLETED" || initStatus === "SUCCESS") {
            raw = initDict;
            functions.logger.info("runImeiCheck: got direct raw result", Object.keys(raw));
        }
        else {
            // Async order → poll /api/track using orderId
            const orderId = (_o = (_m = (_l = (_k = respObj["id"]) !== null && _k !== void 0 ? _k : respObj["orderId"]) !== null && _l !== void 0 ? _l : respObj["order_id"]) !== null && _m !== void 0 ? _m : initDict["id"]) !== null && _o !== void 0 ? _o : initDict["orderId"];
            if (!orderId) {
                throw new functions.https.HttpsError("internal", "imei.org returned no order ID for async tracking.");
            }
            functions.logger.info(`runImeiCheck: async order ${orderId}, polling /track...`);
            let trackedSuccess = false;
            // Poll every 4 seconds, up to 45 attempts (180 seconds = 3 minutes)
            for (let attempt = 0; attempt < 45; attempt++) {
                await new Promise((r) => setTimeout(r, 4000));
                try {
                    const trackRes = await fetch(`https://api-client.imei.org/api/track?apikey=${apiKey}&id=${orderId}`);
                    const trackJson = await trackRes.json();
                    functions.logger.info(`runImeiCheck: track attempt ${attempt + 1}`, JSON.stringify(trackJson).slice(0, 300));
                    if (trackJson.status === 1 && trackJson.response) {
                        const trackDict = _extractRawDict(trackJson.response);
                        const trackStatus = ((_q = (_p = trackDict["Status"]) !== null && _p !== void 0 ? _p : trackDict["status"]) !== null && _q !== void 0 ? _q : "").toString().toUpperCase();
                        const trackHasSpecs = !!(trackDict["Model"] ||
                            trackDict["Full Name"] ||
                            trackDict["Model Desc"] ||
                            trackDict["Manufacturer"] ||
                            trackDict["Model Number"] ||
                            trackDict["Serial"] ||
                            trackDict["Serial Number"]);
                        if (trackStatus === "DONE" || trackStatus === "COMPLETED" || trackStatus === "SUCCESS" || trackHasSpecs) {
                            raw = trackDict;
                            trackedSuccess = true;
                            functions.logger.info("runImeiCheck: track finished successfully", Object.keys(raw));
                            break;
                        }
                        if (trackStatus === "FAILED" || trackStatus === "ERROR" || trackStatus === "CANCELLED" || trackStatus === "REJECT" || trackStatus === "REJECTED") {
                            const failReason = (_t = (_s = (_r = trackDict["message"]) !== null && _r !== void 0 ? _r : trackDict["reason"]) !== null && _s !== void 0 ? _s : trackJson.message) !== null && _t !== void 0 ? _t : `imei.org မှ ထို IMEI စစ်ဆေးမှုကို Reject ပြုလုပ်လိုက်ပါသည် (${serviceName} Server ခေတ္တ အဆင်မပြေခြင်း သို့မဟုတ် အချက်အလက် မရှိခြင်း ဖြစ်နိုင်ပါသည်)`;
                            throw new functions.https.HttpsError("internal", `imei.org API Error: ${failReason}`);
                        }
                    }
                }
                catch (e) {
                    if (e instanceof functions.https.HttpsError)
                        throw e;
                    functions.logger.warn(`runImeiCheck: track attempt ${attempt + 1} exception`, e);
                }
            }
            if (!trackedSuccess || Object.keys(raw).length === 0) {
                throw new functions.https.HttpsError("deadline-exceeded", `imei.org order ${orderId} သည် ကြာမြင့်နေပါသည် (Timeout)။ imei.org တွင် စစ်ဆေးနေဆဲ ဖြစ်နိုင်သောကြောင့် ခဏကြာလျှင် Run API Check ကို ပြန်လည်နှိပ်ပါ။`);
            }
        }
        if (Object.keys(raw).length === 0) {
            throw new functions.https.HttpsError("internal", "imei.org API returned empty result.");
        }
        // ── Step 3: Parse result ─────────────────────────────────────────────────
        const parsed = _parseImeiResult(raw, deviceType || brand);
        // ── Step 4: Save to Firestore (product + imei_registry) ─────────────────
        const checkPayload = {
            imeiCheckRaw: raw,
            imeiCheckParsed: parsed, // full parsed object — Flutter reads this directly
            imeiCheckedAt: firestore_1.FieldValue.serverTimestamp(),
            imeiCheckedBy: context.auth.uid,
            imeiCheckService: serviceName || "TAC",
        };
        // Save to product doc — use set+merge so it works even if doc doesn't exist
        try {
            await db.collection("products").doc(productId).set(checkPayload, { merge: true });
            functions.logger.info(`runImeiCheck: saved to product ${productId}`);
        }
        catch (e) {
            functions.logger.error(`runImeiCheck: product Firestore save failed`, e);
        }
        // Also save to imei_registry for IMEI-centric admin lookup
        if (imei) {
            try {
                await db.collection("imei_registry").doc(imei).set(checkPayload, { merge: true });
                functions.logger.info(`runImeiCheck: saved to imei_registry ${imei}`);
            }
            catch (e) {
                functions.logger.warn(`runImeiCheck: imei_registry save failed for ${imei}`, e);
            }
        }
        return { success: true, parsed, raw };
    }
    catch (err) {
        if (productId) {
            const errMsg = (err === null || err === void 0 ? void 0 : err.message) || String(err);
            const isExplicitReject = errMsg.toLowerCase().includes("reject") || errMsg.toLowerCase().includes("fail");
            const failPayload = {
                imeiCheckRaw: {},
                imeiCheckParsed: {
                    status: isExplicitReject ? "REJECTED" : "TIMEOUT",
                    error: errMsg,
                    errorMessage: errMsg,
                },
                imeiCheckedAt: firestore_1.FieldValue.serverTimestamp(),
                imeiCheckedBy: context.auth.uid,
                imeiCheckService: serviceName || "TAC",
            };
            try {
                await db.collection("products").doc(productId).set(failPayload, { merge: true });
            }
            catch (e) {
                functions.logger.error("Failed to save error to product in catch", e);
            }
        }
        throw err;
    }
});
/* =========================================================
   onAnnouncementCreated — Fan-out to all users
   announcements/{announcementId} create ဖြစ်သည့်အခါ
   users အားလုံးကို FCM + in-app notification (type: announcement) ပို့
========================================================= */
exports.onAnnouncementCreated = functions
    .region("asia-southeast1")
    .firestore.document("announcements/{announcementId}")
    .onCreate(async (snap, context) => {
    var _a, _b;
    const data = snap.data();
    if (!data)
        return;
    const announcementId = context.params.announcementId;
    const title = (_a = data.title) !== null && _a !== void 0 ? _a : "Announcement";
    const body = (_b = data.body) !== null && _b !== void 0 ? _b : "";
    functions.logger.info(`onAnnouncementCreated: ${announcementId} — "${title}"`);
    // ── Get all non-admin users ────────────────────────────────────────────
    let usersSnap;
    try {
        usersSnap = await db.collection("users").get();
    }
    catch (e) {
        functions.logger.error("onAnnouncementCreated: users query failed", e);
        return;
    }
    if (usersSnap.empty)
        return;
    await Promise.allSettled(usersSnap.docs.map(async (userDoc) => {
        var _a, _b;
        const userId = userDoc.id;
        const userData = userDoc.data();
        const role = (_a = userData.role) !== null && _a !== void 0 ? _a : "user";
        const fcmToken = (_b = userData.fcmToken) !== null && _b !== void 0 ? _b : "";
        // admin ကို announcement မပို့ (admin ကိုယ်တိုင် ရေးတာဆိုတော့)
        if (role === "admin")
            return;
        // In-app notification — idempotent doc ID
        try {
            await db.collection("notifications")
                .doc(`announce_${announcementId}_${userId}`)
                .set({
                userId,
                type: "announcement",
                targetRole: role,
                title,
                body,
                announcementId,
                isRead: false,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            functions.logger.warn(`onAnnouncementCreated: notif write failed for ${userId}`, e);
        }
        // FCM push
        if (!fcmToken)
            return;
        try {
            await sendFcmSafe(fcmToken, userId, {
                notification: { title, body },
                data: { type: "announcement", announcementId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
            });
            functions.logger.info(`onAnnouncementCreated: FCM sent to ${userId}`);
        }
        catch (e) {
            functions.logger.warn(`onAnnouncementCreated: FCM failed for ${userId}`, e);
        }
    }));
    functions.logger.info(`onAnnouncementCreated: fan-out done for ${usersSnap.size} users`);
});
exports.onReviewCreated = functions
    .region("asia-southeast1")
    .firestore.document("reviews/{reviewId}")
    .onCreate(async (snap) => {
    var _a, _b;
    const review = snap.data();
    if (!review)
        return;
    const sellerId = (_a = review.sellerId) !== null && _a !== void 0 ? _a : "";
    const rating = (_b = review.rating) !== null && _b !== void 0 ? _b : 0;
    if (!sellerId || rating < 1 || rating > 5) {
        functions.logger.warn("onReviewCreated: invalid data", { sellerId, rating });
        return;
    }
    const sellerRef = db.collection("users").doc(sellerId);
    try {
        await db.runTransaction(async (tx) => {
            var _a, _b;
            const sellerSnap = await tx.get(sellerRef);
            if (!sellerSnap.exists)
                return;
            const data = sellerSnap.data();
            const currentCount = (_a = data.reviewCount) !== null && _a !== void 0 ? _a : 0;
            const currentAvg = (_b = data.avgRating) !== null && _b !== void 0 ? _b : 0;
            const newCount = currentCount + 1;
            const newAvg = (currentAvg * currentCount + rating) / newCount;
            tx.update(sellerRef, {
                reviewCount: newCount,
                avgRating: Math.round(newAvg * 10) / 10, // 1 decimal place
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        });
        functions.logger.info(`onReviewCreated: updated seller ${sellerId} rating +${rating}`);
    }
    catch (e) {
        functions.logger.error(`onReviewCreated: transaction failed for ${sellerId}`, e);
    }
});
/* =========================================================
   onPresenceChanged — RTDB to Firestore Sync
   Trigger: presence/{uid} in Realtime Database changes
   Action: users/{uid}.isOnline and lastSeen fields update in Firestore
   (Bypass client side sync for better reliability on app kill)
========================================================= */
exports.onPresenceChanged = functions
    .region("asia-southeast1")
    .database.ref("presence/{uid}")
    .onWrite(async (change, context) => {
    const data = change.after.val();
    const uid = context.params.uid;
    if (!data)
        return; // ignore delete
    try {
        await db.collection("users").doc(uid).update({
            isOnline: data.isOnline === true,
            lastSeen: data.lastSeen ? firestore_1.Timestamp.fromMillis(data.lastSeen) : firestore_1.FieldValue.serverTimestamp(),
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        functions.logger.info(`Presence sync: user ${uid} → isOnline=${data.isOnline}`);
    }
    catch (e) {
        functions.logger.error(`Presence sync failed for ${uid}`, e);
    }
});
//# sourceMappingURL=index.js.map