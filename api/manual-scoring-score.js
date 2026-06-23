/**
 * POST /api/manual-scoring-score
 *
 * Validates an admin session token against the DB, then proxies to the
 * existing update-closest-call-actuals handler to score a match.
 * Optionally closes the match after scoring.
 *
 * Request headers:
 *   x-admin-token: <token from /api/manual-scoring-auth>
 *
 * Request body:
 *   closest_call_match_id  number   — match to score
 *   question_updates       array    — same format as update-closest-call-actuals
 *   close_match            boolean  — if true, sets match status to 'closed'
 *
 * No MANUAL_SCORING_SECRET env var required.
 */

const { neon }      = require('@neondatabase/serverless');
const updateActuals = require('./update-closest-call-actuals');

const sql = neon(process.env.DATABASE_URL);

async function validateToken(token) {
  if (!token) return null;
  try {
    const rows = await sql`
      SELECT username
      FROM   closest_call_manual_admins
      WHERE  session_token      = ${token}
        AND  session_expires_at > NOW()
        AND  is_active          = TRUE
      LIMIT 1
    `;
    return rows.length ? rows[0] : null;
  } catch {
    return null;
  }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  // ── 1. Validate session token ──────────────────────────────
  const token        = String(req.headers['x-admin-token'] || '').trim();
  const adminSession = await validateToken(token);
  if (!adminSession) {
    return res.status(401).json({ error: 'Unauthorized. Invalid or expired admin session.' });
  }

  const { closest_call_match_id, question_updates, close_match } = req.body || {};
  const matchId = Number(closest_call_match_id);

  if (!matchId || !Array.isArray(question_updates) || question_updates.length === 0) {
    return res.status(400).json({ error: 'closest_call_match_id and question_updates[] are required.' });
  }

  try {
    // ── 2. Proxy to the existing scoring handler ─────────────
    let scoringStatus = 200;
    let scoringResult = null;

    const proxyReq = {
      method:  'POST',
      body:    { closest_call_match_id: matchId, question_updates },
      headers: req.headers,
    };
    const proxyRes = {
      _status: 200,
      status(code) { this._status = code; return this; },
      json(data)   { scoringResult = data; scoringStatus = this._status; },
    };

    await updateActuals(proxyReq, proxyRes);

    if (scoringStatus !== 200) {
      return res.status(scoringStatus).json(scoringResult);
    }

    // ── 3. Optionally close the match ─────────────────────────
    if (close_match) {
      await sql`
        UPDATE closest_call_matches
        SET    status     = 'closed',
               updated_at = NOW()
        WHERE  id = ${matchId}
      `;
    }

    return res.status(200).json({
      success:           true,
      updated_questions: scoringResult?.updated_questions ?? 0,
      match_closed:      !!close_match,
      scored_by:         adminSession.username,
    });

  } catch (error) {
    console.error('manual-scoring-score error:', error);
    return res.status(500).json({ error: error.message || 'Scoring failed. Check server logs.' });
  }
};
