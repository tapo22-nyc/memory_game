const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

// GET /api/refresh-match-player-budgets
// Optional query param: fantasy_match_id=<id>
//   → With param:    refreshes budgets for that one match only
//   → Without param: refreshes all open matches
//
// PREREQUISITE: player_format_scores must be populated first.
// Call /api/refresh-player-format-scores before this if stats changed.

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { fantasy_match_id } = req.query;
    const matchFilter = fantasy_match_id ? Number(fantasy_match_id) : null;

    const result = await sql`
      WITH
        active_players AS (
          SELECT
            fmp.fantasy_match_id,
            fmp.player_id,
            COALESCE(fmp.player_source, 'ipl')                AS player_source,
            COALESCE(ipm.player_name, cpp.player_name)        AS player_name,
            COALESCE(ipm.team_code,   cpp.country)            AS team_name,
            CASE COALESCE(fm.match_format, 'ipl')
              WHEN 'odi'  THEN 'odi'
              WHEN 'test' THEN 'test'
              ELSE 't20'
            END AS score_format
          FROM fantasy_match_players fmp
          JOIN fantasy_matches fm ON fm.id = fmp.fantasy_match_id
          LEFT JOIN ipl_player_master ipm
            ON  ipm.id = fmp.player_id
            AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
          LEFT JOIN cricket_player_pool cpp
            ON  cpp.id = fmp.player_id
            AND fmp.player_source = 'cricket'
          WHERE COALESCE(fmp.is_active, TRUE) = TRUE
            AND (
              ${matchFilter}::INTEGER IS NOT NULL
                AND fmp.fantasy_match_id = ${matchFilter}::INTEGER
              OR
              ${matchFilter}::INTEGER IS NULL
                AND fm.status = 'open'
            )
        ),
        with_scores AS (
          SELECT DISTINCT ON (ap.fantasy_match_id, ap.player_id, ap.player_source)
            ap.*,
            COALESCE(pfs.role,                 'unknown') AS role,
            COALESCE(pfs.final_impact_score,   50.0)      AS final_impact_score,
            COALESCE(pfs.raw_budget_score,     50.0)      AS raw_budget_score,
            COALESCE(pfs.batting_budget_score, 50.0)      AS batting_budget_score,
            COALESCE(pfs.bowling_budget_score, 50.0)      AS bowling_budget_score
          FROM active_players ap
          LEFT JOIN player_format_scores pfs
            ON  LOWER(pfs.player_name) = LOWER(ap.player_name)
            AND pfs.format = ap.score_format
          ORDER BY ap.fantasy_match_id, ap.player_id, ap.player_source,
                   pfs.raw_budget_score DESC NULLS LAST
        ),
        with_side AS (
          SELECT *,
            CASE
              WHEN role IN ('batter', 'wicket_keeper') THEN 'batting'
              WHEN role = 'bowler'                     THEN 'bowling'
              WHEN role = 'all_rounder' THEN
                CASE WHEN batting_budget_score >= bowling_budget_score THEN 'batting' ELSE 'bowling' END
              ELSE 'batting'
            END AS side
          FROM with_scores
        ),
        ranked AS (
          SELECT *,
            ROW_NUMBER() OVER (
              PARTITION BY fantasy_match_id, side
              ORDER BY raw_budget_score DESC, player_id
            ) AS side_rank
          FROM with_side
        ),
        premium_flagged AS (
          SELECT *,
            CASE WHEN side_rank <= 2 THEN TRUE ELSE FALSE END AS is_premium
          FROM ranked
        ),
        tiered AS (
          SELECT *,
            ROW_NUMBER() OVER (
              PARTITION BY fantasy_match_id, is_premium
              ORDER BY raw_budget_score DESC, player_id
            ) AS rank_within_group
          FROM premium_flagged
        ),
        tier_assigned AS (
          SELECT *,
            CASE
              WHEN is_premium             THEN 'premium'
              WHEN rank_within_group <= 8 THEN 'mid'
              ELSE                             'value'
            END AS budget_tier
          FROM tiered
        ),
        tier_bounds AS (
          SELECT
            fantasy_match_id,
            budget_tier,
            MIN(raw_budget_score) AS tier_score_min,
            MAX(raw_budget_score) AS tier_score_max
          FROM tier_assigned
          GROUP BY fantasy_match_id, budget_tier
        ),
        budgeted AS (
          SELECT
            ta.fantasy_match_id, ta.player_id, ta.player_source,
            ta.player_name, ta.team_name, ta.role, ta.score_format,
            ta.final_impact_score, ta.raw_budget_score,
            ta.batting_budget_score, ta.bowling_budget_score,
            ta.budget_tier,
            GREATEST(
              CASE ta.budget_tier WHEN 'premium' THEN 200000 WHEN 'mid' THEN 120000 ELSE 50000 END,
              LEAST(
                CASE ta.budget_tier WHEN 'premium' THEN 250000 WHEN 'mid' THEN 190000 ELSE 120000 END,
                (ROUND((
                  CASE ta.budget_tier WHEN 'premium' THEN 200000 WHEN 'mid' THEN 120000 ELSE 50000 END
                  + CASE
                      WHEN tb.tier_score_max = tb.tier_score_min THEN
                        CASE ta.budget_tier WHEN 'premium' THEN 25000 WHEN 'mid' THEN 35000 ELSE 35000 END
                      ELSE
                        (ta.raw_budget_score - tb.tier_score_min)::NUMERIC
                        / NULLIF(tb.tier_score_max - tb.tier_score_min, 0)
                        * CASE ta.budget_tier WHEN 'premium' THEN 50000 WHEN 'mid' THEN 70000 ELSE 70000 END
                    END
                ) / 5000.0) * 5000)::INTEGER
              )
            )::INTEGER AS final_player_budget
          FROM tier_assigned ta
          JOIN tier_bounds tb
            ON  tb.fantasy_match_id = ta.fantasy_match_id
            AND tb.budget_tier       = ta.budget_tier
        )
      INSERT INTO match_player_budgets (
        fantasy_match_id, player_id, player_source, player_name, team_name,
        role, format, final_impact_score, raw_budget_score,
        batting_budget_score, bowling_budget_score,
        budget_tier, final_player_budget, created_at, updated_at
      )
      SELECT
        fantasy_match_id, player_id, player_source, player_name, team_name,
        role, score_format, final_impact_score, raw_budget_score,
        batting_budget_score, bowling_budget_score,
        budget_tier, final_player_budget, NOW(), NOW()
      FROM budgeted
      ON CONFLICT (fantasy_match_id, player_id, player_source)
      DO UPDATE SET
        player_name          = EXCLUDED.player_name,
        team_name            = EXCLUDED.team_name,
        role                 = EXCLUDED.role,
        format               = EXCLUDED.format,
        final_impact_score   = EXCLUDED.final_impact_score,
        raw_budget_score     = EXCLUDED.raw_budget_score,
        batting_budget_score = EXCLUDED.batting_budget_score,
        bowling_budget_score = EXCLUDED.bowling_budget_score,
        budget_tier          = EXCLUDED.budget_tier,
        final_player_budget  = EXCLUDED.final_player_budget,
        updated_at           = NOW()
      RETURNING fantasy_match_id
    `;

    const matchIds = [...new Set(result.map(r => r.fantasy_match_id))];

    return res.status(200).json({
      success: true,
      rows_upserted: result.length,
      matches_refreshed: matchIds,
      message: `match_player_budgets refreshed for ${matchIds.length} match(es), ${result.length} player rows.`
    });

  } catch (err) {
    console.error('refresh-match-player-budgets error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
};
