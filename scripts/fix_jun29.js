// One-off: corrects the June 29 day document in Firestore to match
// the real values from the morning screenshot.
// Usage: node fix_jun29.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

const UID      = '32u4XTBasheUNP8821IzdIXs00H2';
const DATE_KEY = '2026-06-29';

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function fix() {
  const ref = db.collection('users').doc(UID)
                .collection('days').doc(DATE_KEY);

  await ref.update({
    // Correct targets (what the app actually showed that morning)
    'target.caloriesBase':       2730,
    'target.caloriesAdjusted':   2844,
    'target.activityBonusKcal':  114,
    'target.carbsG':             339,
    'target.fatG':               70,
    'target.fiberG':             35,
    'target.sodiumMg':           2300,
    'target.waterMl':            3000,
    'target.proteinG':           161,

    // Correct consumed totals (already right, but pin them explicitly)
    'consumed.calories':  2856,
    'consumed.carbsG':    376,
    'consumed.fatG':      77,
    'consumed.fiberG':    28,
    'consumed.sodiumMg':  1500,
    'consumed.waterMl':   3300,
  });

  console.log('Done — days/2026-06-29 updated.');
}

fix().catch(console.error);
