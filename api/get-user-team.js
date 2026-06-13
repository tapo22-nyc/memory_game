const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { user_id, fantasy_match_id } = req.query;

    if (!user_id || !fantasy_match_id) {
      return res.status(400).json({ error: 'user_id and fantasy_match_id are required.' });
    }

    const team = await sql`
      SELECT *
      FROM fantasy_user_teams
      WHERE user_id = ${Number(user_id)}
        AND fantasy_match_id = ${Number(fantasy_match_id)}
      LIMIT 1
    `;

    if (!team.length) {
      return res.status(200).json({ team: null, players: [] });
    }

    const players = await sql`
      SELECT
        futp.player_id                                          AS id,
        COALESCE(ipm.player_name, cpp.player_name)             AS player_name,
        COALESCE(ipm.team_code,   cpp.country)                 AS team_name,
        COALESCE(ipm.player_tag,  cpp.player_tag)              AS role,
        COALESCE(ipm.player_type, cpp.player_tag)              AS player_type,
        COALESCE(ipm.auction_price_cr, cpp.player_cost_coins)  AS auction_price_cr,
        COALESCE(ipm.player_cost_coins, cpp.player_cost_coins) AS player_cost_coins,

        futp.player_slot,
        futp.is_active,
        futp.activated_at,
        futp.deactivated_at
      FROM fantasy_user_team_players futp
      LEFT JOIN fantasy_match_players fmp
        ON fmp.player_id        = futp.player_id
       AND fmp.fantasy_match_id = ${team[0].fantasy_match_id}
      LEFT JOIN ipl_player_master ipm
        ON ipm.id = futp.player_id
       AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
      LEFT JOIN cricket_player_pool cpp
        ON cpp.id = futp.player_id
       AND fmp.player_source = 'cricket'
      WHERE futp.fantasy_user_team_id = ${team[0].id}
      ORDER BY
        futp.is_active DESC,
        futp.player_slot,
        COALESCE(ipm.team_code, cpp.country),
        COALESCE(ipm.player_name, cpp.player_name)
    `;

    return res.status(200).json({
      team: team[0],
      players
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
