
const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { user_id } = req.query;

    if (!user_id) {
      return res.status(400).json({ error: 'user_id is required.' });
    }

    const userId = Number(user_id);
    if (!userId || isNaN(userId)) {
      return res.status(400).json({ error: 'user_id must be a valid number.' });
    }

    const rows = await sql`
      SELECT
        booster_type,
        COUNT(*)                        AS times_used,
        COALESCE(SUM(coins_spent), 0)   AS total_coins_spent
      FROM fantasy_user_boosters
      WHERE user_id = ${userId}
        AND status IN ('active', 'reserved', 'used')
      GROUP BY booster_type
      ORDER BY booster_type
    `;

    return res.status(200).json({
      success: true,
      user_id: userId,
      boosters: rows
    });

  } catch (error) {
    console.error('get-booster-usage error:', error);
    return res.status(500).json({ error: error.message || 'Could not fetch booster usage.' });
  }
};
