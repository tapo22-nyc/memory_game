const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { user_id, fantasy_match_id } = req.query;

    if (!user_id || !fantasy_match_id) {
      return res.status(400).json({ error: 'user_id and fantasy_match_id required' });
    }

    // user score
    const score = await sql`
      SELECT *
      FROM fantasy_user_match_scores
      WHERE user_id = ${Number(user_id)}
        AND fantasy_match_id = ${Number(fantasy_match_id)}
    `;

    // player-wise breakdown
    const players = await sql`
      SELECT
        pm.player_name,
        fpms.fantasy_points,
        CASE 
          WHEN fut.captain_player_id = pm.id THEN 'C'
          WHEN fut.vice_captain_player_id = pm.id THEN 'VC'
          ELSE ''
        END AS role
      FROM fantasy_user_teams fut
      JOIN fantasy_user_team_players futp
        ON fut.id = futp.fantasy_user_team_id
      JOIN fantasy_player_match_stats fpms
        ON fpms.player_id = futp.player_id
       AND fpms.fantasy_match_id = fut.fantasy_match_id
      JOIN ipl_player_master pm
        ON pm.id = futp.player_id
      WHERE fut.user_id = ${Number(user_id)}
        AND fut.fantasy_match_id = ${Number(fantasy_match_id)}
    `;

    return res.status(200).json({
      score: score[0] || null,
      players
    });

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
};
