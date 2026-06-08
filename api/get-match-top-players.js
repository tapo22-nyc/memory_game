const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { fantasy_match_id } = req.query;

    if (!fantasy_match_id) {
      return res.status(400).json({ error: 'fantasy_match_id is required' });
    }

    const mid = Number(fantasy_match_id);

    /* Top 3 players by fantasy_points for this match.
       Joins both ipl_player_master (IPL) and cricket_player_pool (international) */
    const players = await sql`
      SELECT
        fpms.player_id,
        fpms.fantasy_points,
        COALESCE(fpms.runs, 0)         AS runs,
        COALESCE(fpms.wickets, 0)      AS wickets,
        COALESCE(fpms.catches, 0)      AS catches,
        COALESCE(fpms.overs_bowled, 0) AS overs_bowled,
        COALESCE(pm.player_name, cpp.player_name) AS player_name,
        COALESCE(pm.team_code,   cpp.country)     AS team_name,
        COALESCE(pm.player_tag,  cpp.player_tag,
                 pm.player_type, cpp.player_type) AS role
      FROM fantasy_player_match_stats fpms
      LEFT JOIN ipl_player_master   pm  ON pm.id  = fpms.player_id
      LEFT JOIN cricket_player_pool cpp ON cpp.id = fpms.player_id
      WHERE fpms.fantasy_match_id = ${mid}
        AND fpms.fantasy_points   IS NOT NULL
        AND fpms.fantasy_points   > 0
      ORDER BY fpms.fantasy_points DESC
      LIMIT 3
    `;

    return res.status(200).json({
      success:          true,
      fantasy_match_id: mid,
      players
    });

  } catch (err) {
    console.error('get-match-top-players error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
};
