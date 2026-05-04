const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { fantasy_match_id } = req.query;

    if (!fantasy_match_id) {
      return res.status(400).json({ error: 'fantasy_match_id is required.' });
    }

    const leaderboard = await sql`
      SELECT
        u.user_name,
        s.user_id,
        s.base_points,
        s.captain_bonus,
        s.vice_captain_bonus,
        s.total_points
      FROM fantasy_user_match_scores s
      JOIN ipl_users u
        ON u.id = s.user_id
      WHERE s.fantasy_match_id = ${Number(fantasy_match_id)}
      ORDER BY s.total_points DESC, s.base_points DESC
    `;

    return res.status(200).json({ leaderboard });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
