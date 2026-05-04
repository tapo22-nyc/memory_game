const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const leaderboard = await sql`
      SELECT
        u.user_name,
        s.user_id,
        SUM(s.total_points) AS total_points,
        SUM(s.base_points) AS base_points,
        SUM(s.captain_bonus) AS captain_bonus,
        SUM(s.vice_captain_bonus) AS vice_captain_bonus,
        COUNT(*) AS matches_played
      FROM fantasy_user_match_scores s
      JOIN ipl_users u
        ON u.id = s.user_id
      GROUP BY u.user_name, s.user_id
      ORDER BY SUM(s.total_points) DESC
    `;

    return res.status(200).json({ leaderboard });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
