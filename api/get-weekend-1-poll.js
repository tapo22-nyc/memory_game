const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

// Update this lock time before deploying.
const WEEKEND_1_POLL_LOCK_TIME = new Date('2026-05-25T14:00:00Z');

const POLL_NAME = 'super_weekend_1';

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const now    = new Date();
    const locked = now >= WEEKEND_1_POLL_LOCK_TIME;

    const userId = req.query.user_id ? Number(req.query.user_id) : null;

    let user_prediction = null;

    if (userId) {
      const rows = await sql`
        SELECT
          v.user_id,
          v.predicted_user_id,
          v.predicted_points_range,
          u.user_name AS predicted_user_name
        FROM weekend_1_poll_votes v
        LEFT JOIN ipl_users u ON u.id = v.predicted_user_id
        WHERE v.user_id   = ${userId}
          AND v.poll_name = ${POLL_NAME}
        LIMIT 1
      `;

      if (rows.length > 0) {
        user_prediction = rows[0];
      }
    }

    return res.status(200).json({
      success:         true,
      poll_name:       POLL_NAME,
      locked,
      lock_time:       WEEKEND_1_POLL_LOCK_TIME.toISOString(),
      user_prediction,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
