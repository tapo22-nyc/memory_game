const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

const OVERALL_START_MATCH_ID = 4;

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  const { fantasy_match_id } = req.query;

  try {
    let rows;

    if (fantasy_match_id) {
      const matchId = Number(fantasy_match_id);

      // Match-wise: pre-filter both sides into CTEs before FULL OUTER JOIN,
      // otherwise unmatched f rows from other matches leak through.
      rows = await sql`
        WITH cc_agg AS (
          SELECT
            p.user_id,
            ccm.id          AS closest_call_match_id,
            SUM(p.points_awarded) AS cc_points
          FROM closest_call_predictions p
          JOIN closest_call_questions  q   ON q.id  = p.question_id
                                          AND q.status = 'scored'
          JOIN closest_call_matches   ccm  ON ccm.id = p.closest_call_match_id
                                          AND ccm.fantasy_match_id = ${matchId}
          GROUP BY p.user_id, ccm.id
        ),
        f11 AS (
          SELECT user_id, total_points, base_points, captain_bonus, vice_captain_bonus
          FROM fantasy_user_match_scores
          WHERE fantasy_match_id = ${matchId}
        )
        SELECT
          u.user_name,
          COALESCE(f.user_id,  cc.user_id)          AS user_id,
          COALESCE(f.total_points,       0)          AS fantasy_11_points,
          COALESCE(f.base_points,        0)          AS base_points,
          COALESCE(f.captain_bonus,      0)          AS captain_bonus,
          COALESCE(f.vice_captain_bonus, 0)          AS vice_captain_bonus,
          COALESCE(cc.cc_points,         0)          AS closest_call_points,
          cc.closest_call_match_id,
          COALESCE(f.total_points, 0) + COALESCE(cc.cc_points, 0) AS combined_total_points,
          1                                          AS matches_played
        FROM cc_agg cc
        FULL OUTER JOIN f11 f ON f.user_id = cc.user_id
        JOIN ipl_users u ON u.id = COALESCE(f.user_id, cc.user_id)
        ORDER BY combined_total_points DESC
      `;

    } else {
      // Overall: aggregate Fantasy 11 across all matches + all Closest Call scored predictions.
      rows = await sql`
        WITH f11 AS (
          SELECT
            user_id,
            SUM(total_points)        AS fantasy_11_points,
            SUM(base_points)         AS base_points,
            SUM(captain_bonus)       AS captain_bonus,
            SUM(vice_captain_bonus)  AS vice_captain_bonus,
            COUNT(*)                 AS matches_played
          FROM fantasy_user_match_scores
          WHERE fantasy_match_id >= ${OVERALL_START_MATCH_ID}
          GROUP BY user_id
        ),
        cc AS (
          SELECT
            p.user_id,
            SUM(p.points_awarded) AS cc_points
          FROM closest_call_predictions p
          JOIN closest_call_questions q ON q.id = p.question_id AND q.status = 'scored'
          GROUP BY p.user_id
        )
        SELECT
          u.user_name,
          COALESCE(f.user_id, cc.user_id)           AS user_id,
          COALESCE(f.fantasy_11_points,  0)          AS fantasy_11_points,
          COALESCE(f.base_points,        0)          AS base_points,
          COALESCE(f.captain_bonus,      0)          AS captain_bonus,
          COALESCE(f.vice_captain_bonus, 0)          AS vice_captain_bonus,
          COALESCE(cc.cc_points,         0)          AS closest_call_points,
          NULL::int                                  AS closest_call_match_id,
          COALESCE(f.fantasy_11_points, 0) + COALESCE(cc.cc_points, 0) AS combined_total_points,
          COALESCE(f.matches_played, 0)              AS matches_played
        FROM f11 f
        FULL OUTER JOIN cc ON cc.user_id = f.user_id
        JOIN ipl_users u ON u.id = COALESCE(f.user_id, cc.user_id)
        ORDER BY combined_total_points DESC
      `;
    }

    return res.status(200).json({
      leaderboard: rows.map(r => ({
        user_id:               Number(r.user_id),
        user_name:             r.user_name,
        fantasy_11_points:     Math.round(Number(r.fantasy_11_points    || 0)),
        base_points:           Math.round(Number(r.base_points          || 0)),
        captain_bonus:         Math.round(Number(r.captain_bonus        || 0)),
        vice_captain_bonus:    Math.round(Number(r.vice_captain_bonus   || 0)),
        closest_call_points:   Math.round(Number(r.closest_call_points  || 0)),
        closest_call_match_id: r.closest_call_match_id ? Number(r.closest_call_match_id) : null,
        combined_total_points: Math.round(Number(r.combined_total_points || 0)),
        matches_played:        r.matches_played != null ? Number(r.matches_played) : undefined,
      })),
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
