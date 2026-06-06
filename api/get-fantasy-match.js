const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { fantasy_match_id } = req.query;

    if (!fantasy_match_id) {
      const matches = await sql`
        SELECT
          fm.id,
          fm.match_title,
          fm.team_1,
          fm.team_2,
          fm.status,
          fm.budget_coins,
          fm.score_update_note,
          COALESCE(fm.match_format, 'ipl') AS match_format,
          im.match_date
        FROM fantasy_matches fm
        LEFT JOIN ipl_matches im ON im.id = fm.ipl_match_id
        ORDER BY fm.id ASC
      `;

      return res.status(200).json({ matches });
    }

    const matches = await sql`
      SELECT
        *,
        COALESCE(match_format, 'ipl') AS match_format
      FROM fantasy_matches
      WHERE id = ${Number(fantasy_match_id)}
      LIMIT 1
    `;

    if (!matches.length) {
      return res.status(404).json({ error: 'Fantasy match not found.' });
    }

    // Unified player query: handles both ipl_player_master and cricket_player_pool.
    // player_source column on fantasy_match_players determines which table to JOIN.
    const players = await sql`
      SELECT
        fmp.player_id                                          AS id,
        COALESCE(ipm.player_name, cpp.player_name)            AS player_name,
        COALESCE(ipm.team_code,   cpp.country)                AS team_name,
        COALESCE(ipm.player_tag,  cpp.player_tag)             AS role,
        COALESCE(ipm.player_type, cpp.player_type)            AS player_type,
        COALESCE(ipm.auction_price_cr, cpp.player_cost_coins) AS auction_price_cr,
        COALESCE(ipm.player_cost_coins, cpp.player_cost_coins) AS player_cost_coins,
        COALESCE(fmp.player_source, 'ipl')                    AS player_source,
        cpp.country                                           AS country
      FROM fantasy_match_players fmp
      LEFT JOIN ipl_player_master ipm
        ON ipm.id = fmp.player_id
        AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
      LEFT JOIN cricket_player_pool cpp
        ON cpp.id = fmp.player_id
        AND fmp.player_source = 'cricket'
      WHERE fmp.fantasy_match_id = ${Number(fantasy_match_id)}
      ORDER BY team_name, player_name
    `;

    return res.status(200).json({
      match: matches[0],
      players
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
