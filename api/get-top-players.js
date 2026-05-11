const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { user_id } = req.query;

    if (!user_id) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    const userId = Number(user_id);
    if (!userId || isNaN(userId)) {
      return res.status(400).json({ error: 'user_id must be a valid number' });
    }

    const players = await sql`
      SELECT
        pm.player_name,
        pm.team_code,
        SUM(fpms.fantasy_points)                                                        AS total_points_earned,
        COUNT(DISTINCT fpms.fantasy_match_id)                                           AS matches_played,
        SUM(CASE WHEN fut.captain_player_id      = futp.player_id THEN 1 ELSE 0 END)   AS times_as_captain,
        SUM(CASE WHEN fut.vice_captain_player_id = futp.player_id THEN 1 ELSE 0 END)   AS times_as_vc
      FROM fantasy_user_team_players futp
      JOIN fantasy_user_teams fut
        ON fut.id = futp.fantasy_user_team_id
      JOIN fantasy_player_match_stats fpms
        ON fpms.player_id        = futp.player_id
       AND fpms.fantasy_match_id = fut.fantasy_match_id
      JOIN ipl_player_master pm
        ON pm.id = futp.player_id
      WHERE fut.user_id            = ${userId}
        AND fpms.fantasy_points    IS NOT NULL
      GROUP BY pm.player_name, pm.team_code, futp.player_id
      ORDER BY total_points_earned DESC
      LIMIT 3
    `;

    return res.status(200).json({ players });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
