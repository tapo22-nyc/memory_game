const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

// GET /api/refresh-player-format-scores
// Deletes and repopulates player_format_scores from player_career_stats_master.
// Call this any time you manually update career stats.
// Takes ~1–3 seconds. Safe to re-run at any time.

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    // Step 1: wipe existing rows
    await sql`DELETE FROM player_format_scores`;

    // Step 2: recalculate and reinsert all players × all formats
    const result = await sql`
      WITH
        player_roles AS (
          SELECT
            p.player_name,
            p.country,
            COALESCE(
              p.player_role,
              CASE COALESCE(cpp.player_type, ipm.player_type)
                WHEN 'Batsman'      THEN 'batter'
                WHEN 'Bowler'       THEN 'bowler'
                WHEN 'All Rounder'  THEN 'all_rounder'
                WHEN 'Wicketkeeper' THEN 'wicket_keeper'
                ELSE 'unknown'
              END
            ) AS role
          FROM player_career_stats_master p
          LEFT JOIN cricket_player_pool cpp
            ON  LOWER(cpp.player_name) = LOWER(p.player_name)
            AND cpp.country = CASE p.country
                  WHEN 'Sri Lanka'   THEN 'SL'
                  WHEN 'West Indies' THEN 'WI'
                  ELSE NULL END
          LEFT JOIN cricapi_player_master ipm
            ON  LOWER(ipm.player_name) = LOWER(p.player_name)
            AND LOWER(ipm.country)     = LOWER(p.country)
        ),
        unpivoted AS (
          SELECT p.player_name, p.country, p.player_pool_source, r.role, 't20' AS format,
            COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
            COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
            COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
            COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
            COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
            COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
          FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
          UNION ALL
          SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi',
            COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
            COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
            COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
            COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
          FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
          UNION ALL
          SELECT p.player_name, p.country, p.player_pool_source, r.role, 'test',
            COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
            COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
            COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0), COALESCE(p.test_bowl_matches,0),
            COALESCE(p.test_bowl_wickets,0), COALESCE(p.test_bowl_economy,99),
            COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
          FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
        ),
        normalized AS (
          SELECT
            player_name, country, player_pool_source, role, format,
            bat_matches, bat_runs, bat_avg, bat_sr,
            bat_50s, bat_100s, bat_4s, bat_6s,
            bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_runs)               * 100)::numeric,1) AS runs_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_avg)                * 100)::numeric,1) AS batting_avg_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_sr)                 * 100)::numeric,1) AS strike_rate_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_50s)                * 100)::numeric,1) AS fifties_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_100s)               * 100)::numeric,1) AS hundreds_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric,1) AS boundary_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_6s)                 * 100)::numeric,1) AS sixes_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_matches)            * 100)::numeric,1) AS bat_experience_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_wickets)           * 100)::numeric,1) AS wickets_score,
            ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_economy))     * 100)::numeric,1) AS economy_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_5wi)               * 100)::numeric,1) AS five_wicket_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_10wi)              * 100)::numeric,1) AS ten_wicket_score,
            ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_matches)           * 100)::numeric,1) AS bowl_experience_score
          FROM unpivoted
        ),
        scored AS (
          SELECT
            player_name, country, player_pool_source, role, format,
            bat_matches, bat_runs, bat_avg, bat_sr, bat_50s, bat_100s, bat_4s, bat_6s,
            bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
            runs_score, batting_avg_score, strike_rate_score, fifties_score,
            hundreds_score, boundary_score, sixes_score, bat_experience_score,
            wickets_score, economy_score, five_wicket_score, ten_wicket_score, bowl_experience_score,
            ROUND(CASE
              WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
              WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
              WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30
            END,1) AS batting_impact_score,
            ROUND(CASE
              WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
              WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
              WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25
            END,1) AS bowling_impact_score,
            ROUND(CASE
              WHEN format='t20'  THEN bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20
              WHEN format='odi'  THEN bat_experience_score*0.20+batting_avg_score*0.40+fifties_score*0.20+hundreds_score*0.20
              WHEN format='test' THEN bat_experience_score*0.20+batting_avg_score*0.30+fifties_score*0.25+hundreds_score*0.25
            END,1) AS batting_budget_score,
            ROUND(CASE
              WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40
              WHEN format='test'           THEN bowl_experience_score*0.20+wickets_score*0.30+five_wicket_score*0.25+ten_wicket_score*0.25
            END,1) AS bowling_budget_score
          FROM normalized
        ),
        combined AS (
          SELECT
            player_name, country, player_pool_source, role, format,
            bat_matches, bat_runs, bat_avg, bat_sr, bat_50s, bat_100s, bat_4s, bat_6s,
            bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
            runs_score, batting_avg_score, strike_rate_score, fifties_score,
            hundreds_score, boundary_score, sixes_score, bat_experience_score,
            wickets_score, economy_score, five_wicket_score, ten_wicket_score, bowl_experience_score,
            batting_impact_score, bowling_impact_score,
            batting_budget_score, bowling_budget_score,
            GREATEST(0,LEAST(100,ROUND(CASE
              WHEN role='batter'        THEN batting_impact_score
              WHEN role='wicket_keeper' THEN batting_impact_score
              WHEN role='bowler'        THEN bowling_impact_score
              WHEN role='all_rounder'   THEN batting_impact_score*0.50+bowling_impact_score*0.50
              ELSE (batting_impact_score+bowling_impact_score)/2
            END,1))) AS final_impact_score,
            GREATEST(0,LEAST(100,ROUND(CASE
              WHEN role='batter'        THEN batting_budget_score
              WHEN role='wicket_keeper' THEN batting_budget_score
              WHEN role='bowler'        THEN bowling_budget_score
              WHEN role='all_rounder'   THEN batting_budget_score*0.50+bowling_budget_score*0.50
              ELSE (batting_budget_score+bowling_budget_score)/2
            END,1))) AS raw_budget_score
          FROM scored
        )
      INSERT INTO player_format_scores (
        player_name, country, player_pool_source, role, format,
        bat_matches, bat_runs, bat_avg, bat_sr, bat_50s, bat_100s, bat_4s, bat_6s,
        bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
        runs_score, batting_avg_score, strike_rate_score, fifties_score,
        hundreds_score, boundary_score, sixes_score, bat_experience_score,
        wickets_score, economy_score, five_wicket_score, ten_wicket_score,
        bowl_experience_score,
        batting_impact_score, bowling_impact_score, final_impact_score,
        batting_budget_score, bowling_budget_score, raw_budget_score,
        created_at, updated_at
      )
      SELECT
        player_name, country, player_pool_source, role, format,
        bat_matches, bat_runs, bat_avg, bat_sr, bat_50s, bat_100s, bat_4s, bat_6s,
        bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
        runs_score, batting_avg_score, strike_rate_score, fifties_score,
        hundreds_score, boundary_score, sixes_score, bat_experience_score,
        wickets_score, economy_score, five_wicket_score, ten_wicket_score,
        bowl_experience_score,
        batting_impact_score, bowling_impact_score, final_impact_score,
        batting_budget_score, bowling_budget_score, raw_budget_score,
        NOW(), NOW()
      FROM combined
      RETURNING id
    `;

    return res.status(200).json({
      success: true,
      rows_inserted: result.length,
      message: `player_format_scores refreshed with ${result.length} rows.`
    });

  } catch (err) {
    console.error('refresh-player-format-scores error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
};
