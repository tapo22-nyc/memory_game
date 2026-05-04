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
        pm.id,
        pm.player_name,
        pm.team_code AS team_name,
        pm.player_tag AS role,
        pm.auction_price_cr,
        pm.player_cost_coins
      FROM fantasy_user_team_players futp
      JOIN ipl_player_master pm
        ON pm.id = futp.player_id
      WHERE futp.fantasy_user_team_id = ${team[0].id}
      ORDER BY pm.team_code, pm.player_name
    `;

    return res.status(200).json({
      team: team[0],
      players
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
