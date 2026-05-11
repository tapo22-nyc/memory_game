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

    const balanceRows = await sql`
      WITH earned AS (
        SELECT
          COALESCE(SUM(total_points), 0) AS total_points_earned
        FROM fantasy_user_match_scores
        WHERE user_id = ${userId}
      ),
      spent AS (
        SELECT
          COALESCE(SUM(ABS(coins)), 0) AS total_coins_spent
        FROM fantasy_user_coin_ledger
        WHERE user_id = ${userId}
          AND transaction_type = 'debit'
      )
      SELECT
        earned.total_points_earned,
        earned.total_points_earned AS lifetime_coins_earned,
        spent.total_coins_spent,
        earned.total_points_earned - spent.total_coins_spent AS available_coins
      FROM earned, spent
    `;

    return res.status(200).json({
      success: true,
      user_id: userId,
      balance: balanceRows[0]
    });

  } catch (error) {
    console.error('get-user-coin-balance error:', error);

    return res.status(500).json({
      error: error.message || 'Could not fetch coin balance.'
    });
  }
};
