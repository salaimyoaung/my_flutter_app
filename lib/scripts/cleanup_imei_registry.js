// cleanup_imei_registry.js
// Deletes all imei_registry docs that have no matching product in Firestore.
// Run: node cleanup_imei_registry.js

const admin = require('firebase-admin');
const serviceAccount = require('../../../functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function cleanup() {
  const imeiSnap = await db.collection('imei_registry').get();
  if (imeiSnap.empty) {
    console.log('imei_registry is already empty.');
    return;
  }

  console.log(`Found ${imeiSnap.size} imei_registry docs. Checking...`);

  const batch = db.batch();
  let deleteCount = 0;

  for (const doc of imeiSnap.docs) {
    const productId = doc.data().productId;
    let orphan = true;

    if (productId) {
      const productSnap = await db.collection('products').doc(productId).get();
      if (productSnap.exists) orphan = false;
    }

    if (orphan) {
      console.log(`  ✗ orphan: ${doc.id} (productId: ${productId ?? 'none'})`);
      batch.delete(doc.ref);
      deleteCount++;
    } else {
      console.log(`  ✓ valid:  ${doc.id}`);
    }
  }

  if (deleteCount === 0) {
    console.log('No orphans found.');
    return;
  }

  await batch.commit();
  console.log(`\nDeleted ${deleteCount} orphaned imei_registry docs.`);
}

cleanup().catch(console.error);
