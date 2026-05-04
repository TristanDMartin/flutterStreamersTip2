/**
 * One-off: set Firestore admin fields + Auth custom claims for founder emails.
 *
 * Usage (from cloud_functions/, with GOOGLE_APPLICATION_CREDENTIALS or
 * `firebase login` application default credentials):
 *   node scripts/grant_admin_claims.js
 *
 * Edit ADMINS below, then run. Prefer UID-based promotion after verifyUser.
 */
const admin = require('firebase-admin');

const ADMINS = [
  {email: 'technqs@gmail.com'},
  {email: 'buzzz@email.com'},
];

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const db = admin.firestore();
  for (const row of ADMINS) {
    let user;
    try {
      user = await admin.auth().getUserByEmail(row.email);
    } catch (e) {
      console.warn('skip (no auth user)', row.email, e.message);
      continue;
    }
    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true,
      tier: 'studio',
    });
    await db.collection('users').doc(user.uid).set(
      {
        role: 'admin',
        subscriptionTier: 'studio',
        admin: {
          isAdmin: true,
          permissions: ['*'],
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    console.log('ok', row.email, user.uid);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
