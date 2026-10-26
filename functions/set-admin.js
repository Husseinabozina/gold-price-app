'use strict';
// Usage: GOOGLE_APPLICATION_CREDENTIALS=/secure/path/account.json node scripts/set-admin.js <FIREBASE_AUTH_UID>
// Never commit service account credentials. Run once from a trusted admin machine.
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const uid=process.argv[2];
if (!uid || uid.length<5) {
  console.error('Provide the real Firebase Authentication UID as argument.');
  process.exit(1);
}
initializeApp();
getAuth().setCustomUserClaims(uid,{admin:true}).then(()=>{
  console.log('Granted admin claim for UID:',uid);
  console.log('Sign out and sign in again to refresh the token.');
}).catch((e)=>{console.error(e);process.exitCode=1;});
