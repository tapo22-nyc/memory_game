import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const fantasyMatchId = Number(req.query.fantasy_match_id);

    if (!fantasyMatchId) {
      return res.status(400).json({ error: 'Missing fantasy_match_id' });
    }

    await sql`
      INSERT INTO fantasy_user_match_scores
        (user_id, fantasy_match_id, base_points, captain_bonus, vice_captain_bonus, total_points)

      WITH active_player_points AS (
        SELECT
          fut.user_id,
          fut.fantasy_match_id,
          fut.captain_player_id,
          fut.vice_captain_player_id,
          fut.use_captain_booster,
          fut.use_vc_booster,
          futp.player_id,
          COALESCE(fpms.fantasy_points, 0) AS fantasy_points
        FROM fantasy_user_teams fut
        JOIN fantasy_user_team_players futp
          ON fut.id = futp.fantasy_user_team_id
        LEFT JOIN fantasy_player_match_stats fpms
          ON  fpms.player_id = futp.player_id
          AND fpms.fantasy_match_id = fut.fantasy_match_id
        WHERE fut.fantasy_match_id = ${fantasyMatchId}
          AND futp.is_active = TRUE
      ),

      frozen_sub_points AS (
        SELECT
          user_id,
          fantasy_match_id,
          SUM(COALESCE(player_out_frozen_points, 0)) AS frozen_points
        FROM fantasy_user_substitutions
        WHERE fantasy_match_id = ${fantasyMatchId}
        GROUP BY user_id, fantasy_match_id
      )

      SELECT
        app.user_id,
        app.fantasy_match_id,

        SUM(app.fantasy_points) + COALESCE(MAX(fsp.frozen_points), 0) AS base_points,

        SUM(
          CASE
            WHEN app.player_id = app.captain_player_id
            THEN app.fantasy_points * CASE WHEN app.use_captain_booster THEN 2 ELSE 1 END
            ELSE 0
          END
        ) AS captain_bonus,

        SUM(
          CASE
            WHEN app.player_id = app.vice_captain_player_id
            THEN app.fantasy_points * CASE WHEN app.use_vc_booster THEN 1.0 ELSE 0.5 END
            ELSE 0
          END
        ) AS vice_captain_bonus,

        SUM(app.fantasy_points)
          + COALESCE(MAX(fsp.frozen_points), 0)
          + SUM(
              CASE
                WHEN app.player_id = app.captain_player_id
                THEN app.fantasy_points * CASE WHEN app.use_captain_booster THEN 2 ELSE 1 END
                ELSE 0
              END
            )
          + SUM(
              CASE
                WHEN app.player_id = app.vice_captain_player_id
                THEN app.fantasy_points * CASE WHEN app.use_vc_booster THEN 1.0 ELSE 0.5 END
                ELSE 0
              END
            ) AS total_points

      FROM active_player_points app
      LEFT JOIN frozen_sub_points fsp
        ON  fsp.user_id = app.user_id
        AND fsp.fantasy_match_id = app.fantasy_match_id
      GROUP BY app.user_id, app.fantasy_match_id

      ON CONFLICT (user_id, fantasy_match_id)
      DO UPDATE SET
        base_points = EXCLUDED.base_points,
        captain_bonus = EXCLUDED.captain_bonus,
        vice_captain_bonus = EXCLUDED.vice_captain_bonus,
        total_points = EXCLUDED.total_points,
        calculated_at = CURRENT_TIMESTAMP
    `;

    const leaderboard = await sql`
      SELECT
        u.user_name,
        s.base_points,
        s.captain_bonus,
        s.vice_captain_bonus,
        s.total_points
      FROM fantasy_user_match_scores s
      JOIN ipl_users u
        ON u.id = s.user_id
      WHERE s.fantasy_match_id = ${fantasyMatchId}
      ORDER BY s.total_points DESC
      LIMIT 20
    `;

    return res.status(200).json({
      message: 'Fantasy user scores recalculated successfully',
      fantasy_match_id: fantasyMatchId,
      leaderboard
    });

  } catch (error) {
    console.error('recalculate-fantasy-user-scores error:', error);
    return res.status(500).json({ error: error.message });
  }
}
