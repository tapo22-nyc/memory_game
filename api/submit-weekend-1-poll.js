const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

// Update this lock time before deploying.
const WEEKEND_1_POLL_LOCK_TIME = new Date('2026-05-25T14:00:00Z');

const POLL_NAME = 'super_weekend_1';

const VALID_POINTS_RANGES = ['<1000', '1000-1500', '1500-2000', '2000-2500', '2500+'];

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  try {
    const { user_id, predicted_user_id, predicted_points_range } = req.body;

    if (!user_id || !predicted_user_id || !predicted_points_range) {
      return res.status(400).json({ error: 'user_id, predicted_user_id, and predicted_points_range are required.' });
    }

    if (!VALID_POINTS_RANGES.includes(predicted_points_range)) {
      return res.status(400).json({ error: `Invalid predicted_points_range. Must be one of: ${VALID_POINTS_RANGES.join(', ')}` });
    }

    const now = new Date();
    if (now >= WEEKEND_1_POLL_LOCK_TIME) {
      return res.status(403).json({ error: 'Poll is locked. Predictions can no longer be changed.' });
    }

    const userId          = Number(user_id);
    const predictedUserId = Number(predicted_user_id);

    // Validate user exists
    const userRows = await sql`SELECT id FROM ipl_users WHERE id = ${userId} LIMIT 1`;
    if (userRows.length === 0) {
      return res.status(400).json({ error: 'Invalid user_id.' });
    }

    // Validate predicted user exists
    const predictedRows = await sql`SELECT id FROM ipl_users WHERE id = ${predictedUserId} LIMIT 1`;
    if (predictedRows.length === 0) {
      return res.status(400).json({ error: 'Invalid predicted_user_id.' });
    }

    // Upsert — one vote per user per poll_name; update both answers on conflict
    await sql`
      INSERT INTO weekend_1_poll_votes
        (user_id, predicted_user_id, predicted_points_range, poll_name, created_at, updated_at)
      VALUES
        (${userId}, ${predictedUserId}, ${predicted_points_range}, ${POLL_NAME}, now(), now())
      ON CONFLICT (user_id, poll_name)
      DO UPDATE SET
        predicted_user_id      = EXCLUDED.predicted_user_id,
        predicted_points_range = EXCLUDED.predicted_points_range,
        updated_at             = now()
    `;

    return res.status(200).json({
      success: true,
      prediction: {
        user_id:               userId,
        predicted_user_id:     predictedUserId,
        predicted_points_range,
        poll_name:             POLL_NAME,
      },
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
