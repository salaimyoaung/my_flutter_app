const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.cert(
    require("./serviceAccountKey.json")
  ),
});

const db = admin.firestore();

function normLower(s) {
  return String(s).toLowerCase().replace(/\s+/g, " ").trim();
}

(async () => {
  const snap = await db.collection("phone_brands").get();
  console.log("Found:", snap.size);

  let batch = db.batch();
  let ops = 0;
  let updated = 0, skipped = 0;

  async function commitIfNeeded(force = false) {
    if (ops === 0) return;
    if (!force && ops < 450) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
    console.log("Committed chunk...");
  }

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const name = (data.name || "").trim();
    if (!name) {
      skipped++;
      console.log("SKIP", doc.id, "missing name");
      continue;
    }

    const patch = {};
    const nameLower = normLower(name);

    if (!data.nameLower || String(data.nameLower) !== nameLower) {
      patch.nameLower = nameLower;
    }
    if (!("order" in data)) patch.order = 9999;
    if (!("active" in data)) patch.active = true;

    patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    if (Object.keys(patch).length === 1) {
      skipped++;
      continue;
    }

    batch.set(doc.ref, patch, { merge: true });
    ops++;
    updated++;

    if (ops >= 450) await commitIfNeeded(true);
  }

  await commitIfNeeded(true);
  console.log("DONE ✅ updated=", updated, "skipped=", skipped);
  process.exit(0);
})().catch((e) => {
  console.error("ERROR", e);
  process.exit(1);
});