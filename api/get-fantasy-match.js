const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { fantasy_match_id } = req.query;

    // No ID: return all matches for homepage cards
    if (!fantasy_match_id) {
      const matches = await sql`
        SELECT
          id,
          match_title,
          team_1,
          team_2,
          status,
          budget_coins
        FROM fantasy_matches
        ORDER BY id ASC
      `;

      return res.status(200).json({ matches });
    }

    // ID provided: return one match + players
    const matches = await sql`
      SELECT *
      FROM fantasy_matches
      WHERE id = ${Number(fantasy_match_id)}
      LIMIT 1
    `;

    if (!matches.length) {
      return res.status(404).json({ error: 'Fantasy match not found.' });
    }

    const players = await sql`
      SELECT
        pm.id,
        pm.player_name,
        pm.team_code AS team_name,
        pm.player_tag AS role,
        pm.auction_price_cr,
        pm.player_cost_coins
      FROM fantasy_match_players fmp
      JOIN ipl_player_master pm
        ON pm.id = fmp.player_id
      WHERE fmp.fantasy_match_id = ${Number(fantasy_match_id)}
      ORDER BY pm.team_code, pm.player_name
    `;

    return res.status(200).json({
      match: matches[0],
      players
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
