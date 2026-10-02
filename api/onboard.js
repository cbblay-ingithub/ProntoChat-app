const admin = require('firebase-admin');

// Helper to initialize Firebase Admin SDK using environment variables
function initFirebaseAdmin() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = typeof process.env.FIREBASE_SERVICE_ACCOUNT === 'string'
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      : process.env.FIREBASE_SERVICE_ACCOUNT;
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const projectId = process.env.FIREBASE_PROJECT_ID || 'prontochat-3b974';
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY
    ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
    : undefined;

  if (clientEmail && privateKey) {
    return admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }

  // Fallback default initialization
  return admin.initializeApp({ projectId });
}

/**
 * Vercel Serverless Function: Onboarding & Pre-approval Verification
 * POST /api/onboard
 * Body: { firmId, email, uid (optional), action: "check" | "claim" }
 */
module.exports = async (req, res) => {
  // CORS Handling
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed. Use POST.' });
  }

  try {
    const app = initFirebaseAdmin();
    const db = admin.firestore(app);

    const { firmId, email, uid, action = 'check' } = req.body || {};

    if (!firmId || !email) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: firmId and email are required.',
      });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Check PreApprovedStaff collection for the firm
    const staffDocRef = db
      .collection('Firms')
      .doc(firmId)
      .collection('PreApprovedStaff')
      .doc(cleanEmail);

    const staffDoc = await staffDocRef.get();

    if (!staffDoc.exists) {
      return res.status(200).json({
        success: true,
        isPreApproved: false,
        message: `Email ${cleanEmail} is not pre-approved for firm ${firmId}.`,
      });
    }

    const staffData = staffDoc.data();

    // Action: claim - mark pre-approved invitation as joined
    if (action === 'claim' && uid) {
      await staffDocRef.update({
        status: 'joined',
        claimedByUid: uid,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Auto-create or approve membership doc in Memberships collection
      await db.collection('Memberships').doc(uid).set({
        uid: uid,
        firmId: firmId,
        email: cleanEmail,
        role: 'employee',
        status: 'approved',
        jobTitle: staffData.jobTitle || 'Employee',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return res.status(200).json({
        success: true,
        isPreApproved: true,
        claimed: true,
        membershipStatus: 'approved',
        staffData,
      });
    }

    return res.status(200).json({
      success: true,
      isPreApproved: true,
      status: staffData.status || 'invited',
      name: staffData.name,
      jobTitle: staffData.jobTitle,
    });
  } catch (error) {
    console.error('Serverless onboarding error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Internal Server Error',
    });
  }
};
