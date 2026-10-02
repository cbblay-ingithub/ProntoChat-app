const admin = require('firebase-admin');

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

  return admin.initializeApp({ projectId });
}

/**
 * Vercel Serverless Function: Administrative Operations
 * POST /api/admin
 * Actions: "approveMember", "rejectMember", "verifyFirm"
 */
module.exports = async (req, res) => {
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

    const { action, firmId, targetUid, status } = req.body || {};

    if (!action || !firmId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: action and firmId.',
      });
    }

    if (action === 'verifyFirm') {
      const firmDoc = await db.collection('Firms').doc(firmId).get();
      if (!firmDoc.exists) {
        return res.status(200).json({ success: true, exists: false });
      }
      const data = firmDoc.data();
      return res.status(200).json({
        success: true,
        exists: true,
        firmId: firmDoc.id,
        name: data.name,
        adminId: data.adminId,
        createdAt: data.createdAt,
      });
    }

    if (action === 'updateMemberStatus' && targetUid && status) {
      // Update Membership doc
      await db.collection('Memberships').doc(targetUid).update({
        status: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.status(200).json({
        success: true,
        targetUid,
        status,
        message: `Membership status updated to ${status}.`,
      });
    }

    return res.status(400).json({
      success: false,
      error: `Unknown action '${action}'.`,
    });
  } catch (error) {
    console.error('Serverless admin error:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Internal Server Error',
    });
  }
};
