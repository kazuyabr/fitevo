// Deletes every Firebase Auth user AND their Firestore data
// EXCEPT the one UID listed below.
// Usage:
//   1. Place serviceAccount.json in this folder (gitignored)
//   2. npm install   (run once)
//   3. node delete_other_users.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

const KEEP_UID = '32u4XTBasheUNP8821IzdIXs00H2';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteOtherUsers() {
  // ── 1. Delete Auth users ────────────────────────────────────────────────
  let pageToken;
  const toDelete = [];

  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    for (const user of result.users) {
      if (user.uid !== KEEP_UID) {
        toDelete.push(user.uid);
        console.log(`Auth  delete: ${user.uid}  (${user.email ?? 'no email'})`);
      } else {
        console.log(`Auth  keep:   ${user.uid}  (${user.email ?? 'no email'})`);
      }
    }
    pageToken = result.pageToken;
  } while (pageToken);

  if (toDelete.length > 0) {
    const authResult = await admin.auth().deleteUsers(toDelete);
    console.log(`\nAuth deleted: ${authResult.successCount}`);
    if (authResult.failureCount > 0) {
      authResult.errors.forEach(e => console.error(e));
    }
  } else {
    console.log('\nNo extra Auth users to delete.');
  }

  // ── 2. Delete Firestore docs for all users except KEEP_UID ─────────────
  const usersSnap = await db.collection('users').get();
  const firestoreToDelete = usersSnap.docs
    .map(d => d.id)
    .filter(uid => uid !== KEEP_UID);

  if (firestoreToDelete.length === 0) {
    console.log('No extra Firestore user docs to delete.');
  } else {
    console.log(`\nFirestore deleting ${firestoreToDelete.length} user doc(s)…`);
    for (const uid of firestoreToDelete) {
      console.log(`  Deleting users/${uid}`);
      // recursiveDelete removes the doc + all subcollections automatically.
      await db.recursiveDelete(db.collection('users').doc(uid));
    }
    console.log('Firestore cleanup done.');
  }

  console.log('\nAll done.');
}

deleteOtherUsers().catch(console.error);
