const admin = require("firebase-admin");

// Use the existing service account key in the scripts folder
admin.initializeApp({
  credential: admin.credential.cert(
    require("./serviceAccountKey.json")
  ),
});

const db = admin.firestore();

(async () => {
  console.log("Starting comprehensive cleanup for products...");

  // Query: all products that are currently active
  const snap = await db.collection("products")
    .where("active", "==", true)
    .get();

  console.log(`Found ${snap.size} active products to check.`);

  let batch = db.batch();
  let ops = 0;
  let fixedSold = 0;
  let fixedRejected = 0;

  async function commitBatch() {
    if (ops > 0) {
      await batch.commit();
      console.log(`Committed batch of ${ops} updates.`);
      batch = db.batch();
      ops = 0;
    }
  }

  for (const doc of snap.docs) {
    const data = doc.data();
    let shouldDeactivate = false;
    let reason = "";

    // 1. If it has a soldAt timestamp but is active: true
    if (data.soldAt != null) {
      shouldDeactivate = true;
      reason = "Sold (has soldAt)";
      fixedSold++;
    }
    // 2. If it was REJECTED by admin but is active: true
    else if (data.imeiStatus === "REJECTED") {
      shouldDeactivate = true;
      reason = "Rejected imeiStatus";
      fixedRejected++;
    }

    if (shouldDeactivate) {
      batch.update(doc.ref, {
        active: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        cleanupNote: `Auto-deactivated: ${reason}`
      });

      ops++;

      // Firestore batches are limited to 500 operations
      if (ops >= 400) {
        await commitBatch();
      }
    }
  }

  await commitBatch();

  console.log("-----------------------------------------");
  console.log(`Cleanup DONE ✅`);
  console.log(`Sold products fixed: ${fixedSold}`);
  console.log(`Rejected products fixed: ${fixedRejected}`);
  console.log(`Total fixed: ${fixedSold + fixedRejected}`);
  console.log("-----------------------------------------");

  process.exit(0);
})().catch((e) => {
  console.error("ERROR during cleanup:", e);
  process.exit(1);
});