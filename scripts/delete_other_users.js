// Deletes every Firebase Auth user EXCEPT the one UID listed below.
// Usage:
//   1. Download service account key from Firebase Console →
//      Project Settings → Service Accounts → Generate new private key
//      Save it as scripts/serviceAccount.json (gitignored)
//   2. npm install firebase-admin   (run once inside scripts/)
//   3. node scripts/delete_other_users.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

const KEEP_UID = '32u4XTBasheUNP8821IzdIXs00H2';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function deleteOtherUsers() {
  let pageToken;
  const toDelete = [];

  // List all users, page by page.
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    for (const user of result.users) {
      if (user.uid !== KEEP_UID) {
        toDelete.push(user.uid);
        console.log(`Will delete: ${user.uid}  (${user.email ?? 'no email'})`);
      } else {
        console.log(`Keeping:     ${user.uid}  (${user.email ?? 'no email'})`);
      }
    }
    pageToken = result.pageToken;
  } while (pageToken);

  if (toDelete.length === 0) {
    console.log('\nNo other users found — nothing to delete.');
    return;
  }

  console.log(`\nDeleting ${toDelete.length} user(s)…`);
  const result = await admin.auth().deleteUsers(toDelete);
  console.log(`Deleted: ${result.successCount}`);
  if (result.failureCount > 0) {
    console.error(`Failed:  ${result.failureCount}`);
    result.errors.forEach(e => console.error(e));
  }
  console.log('Done.');
}

deleteOtherUsers().catch(console.error);
