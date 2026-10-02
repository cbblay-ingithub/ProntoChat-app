/**
 * Vercel Serverless Function: Health & Spark Plan Audit Status Check
 * GET /api/health
 */
module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  return res.status(200).json({
    status: 'ok',
    mode: 'spark-free-tier',
    cloudFunctionsRequired: false,
    timestamp: new Date().toISOString(),
    service: 'ProntoChat Vercel Serverless Bridge',
  });
};
