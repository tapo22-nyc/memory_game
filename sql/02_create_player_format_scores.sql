-- ============================================================
-- FILE: sql/02_create_player_format_scores.sql
-- PURPOSE: Create player_format_scores — one row per player
--          per format (t20/odi/test) storing all percentile
--          component scores, impact scores, and raw budget score.
--
-- WHAT THIS DOES:
--   Step 1 — CREATE TABLE player_format_scores
--   Step 2 — REFRESH query (DELETE + INSERT from master stats)
--   Step 3 — Verify counts
--
-- GLOBAL SCORING NOTE:
--   Percentile scores are calculated across ALL players in
--   player_career_stats_master within the same (format, role).
--   This means a batter's runs_score is their percentile among
--   all batters — not against bowlers. This is correct.
--
--   Match-specific budget tiers are in match_player_budgets
--   (see FILE 3). This table is the input to FILE 3.
--
-- RECOMMENDED REFRESH APPROACH:
--   Do NOT use a database trigger — triggers cause unexpected
--   behavior in Neon serverless and make debugging hard.
--   Instead: call GET /api/refresh-player-format-scores
--   after any manual update to player_career_stats_master.
--
-- SAFE TO RE-RUN: Step 1 uses IF NOT EXISTS.
--                 Step 2 (REFRESH) deletes and re-inserts.
-- ============================================================


-- ============================================================
-- STEP 1: CREATE TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS player_format_scores (

  id                    SERIAL PRIMARY KEY,

  -- ── Player identity ──────────────────────────────────────
  player_name           TEXT          NOT NULL,
  country               TEXT          NOT NULL,
  player_pool_source    TEXT          NOT NULL DEFAULT 'cricket',
  role                  TEXT          NOT NULL DEFAULT 'unknown',
  format                TEXT          NOT NULL,   -- 't20', 'odi', 'test'

  -- ── Raw stat values stored for reference ─────────────────
  bat_matches           INTEGER       DEFAULT 0,
  bat_runs              INTEGER       DEFAULT 0,
  bat_avg               NUMERIC(7,2)  DEFAULT 0,
  bat_sr                NUMERIC(7,2)  DEFAULT 0,
  bat_50s               INTEGER       DEFAULT 0,
  bat_100s              INTEGER       DEFAULT 0,
  bat_4s                INTEGER       DEFAULT 0,
  bat_6s                INTEGER       DEFAULT 0,
  bowl_matches          INTEGER       DEFAULT 0,
  bowl_wickets          INTEGER       DEFAULT 0,
  bowl_economy          NUMERIC(5,2)  DEFAULT 99,
  bowl_5wi              INTEGER       DEFAULT 0,
  bowl_10wi             INTEGER       DEFAULT 0,

  -- ── Percentile scores (0–100, within role+format group) ──
  runs_score            NUMERIC(5,1),
  batting_avg_score     NUMERIC(5,1),
  strike_rate_score     NUMERIC(5,1),
  fifties_score         NUMERIC(5,1),
  hundreds_score        NUMERIC(5,1),
  boundary_score        NUMERIC(5,1),
  sixes_score           NUMERIC(5,1),
  bat_experience_score  NUMERIC(5,1),
  wickets_score         NUMERIC(5,1),
  economy_score         NUMERIC(5,1),
  five_wicket_score     NUMERIC(5,1),
  ten_wicket_score      NUMERIC(5,1),
  bowl_experience_score NUMERIC(5,1),

  -- ── Composite impact scores (0–100, clamped) ─────────────
  batting_impact_score  NUMERIC(5,1),
  bowling_impact_score  NUMERIC(5,1),
  final_impact_score    NUMERIC(5,1),

  -- ── Budget scores (0–100, clamped) ───────────────────────
  -- Stored separately so all_rounder side (batting vs bowling)
  -- can be determined in match_player_budgets (FILE 3).
  batting_budget_score  NUMERIC(5,1),
  bowling_budget_score  NUMERIC(5,1),
  raw_budget_score      NUMERIC(5,1),

  -- ── Metadata ─────────────────────────────────────────────
  created_at            TIMESTAMP     DEFAULT NOW(),
  updated_at            TIMESTAMP     DEFAULT NOW(),

  UNIQUE (player_name, country, format)
);

CREATE INDEX IF NOT EXISTS idx_pfs_player_format
  ON player_format_scores (player_name, format);

CREATE INDEX IF NOT EXISTS idx_pfs_role_format
  ON player_format_scores (role, format);


-- ============================================================
-- STEP 2: REFRESH — delete all rows and recalculate from
-- player_career_stats_master.
--
-- Run this entire block each time you update career stats.
-- The window functions re-rank ALL players so percentiles
-- stay accurate after any change.
--
-- WARNING: This deletes all existing rows first. The table
-- will be briefly empty during the ~1 second re-insert.
-- This is acceptable since this is a background operation.
-- ============================================================

DELETE FROM player_format_scores;

WITH

  -- ── Resolve role from source tables (same as deploy_impact_budget.sql) ──
  player_roles AS (
    SELECT
      p.player_name,
      p.country,
      COALESCE(
        p.player_role,   -- use denormalized role if already backfilled (FILE 1 Step 3)
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

  -- ── Unpivot: one row per player per format ────────────────
  unpivoted AS (
    SELECT p.player_name, p.country, p.player_pool_source, r.role, 't20' AS format,
      COALESCE(p.t20_bat_matches,0)    AS bat_matches,
      COALESCE(p.t20_bat_runs,0)       AS bat_runs,
      COALESCE(p.t20_bat_avg,0)        AS bat_avg,
      COALESCE(p.t20_bat_strike_rate,0)AS bat_sr,
      COALESCE(p.t20_bat_50s,0)        AS bat_50s,
      COALESCE(p.t20_bat_100s,0)       AS bat_100s,
      COALESCE(p.t20_bat_4s,0)         AS bat_4s,
      COALESCE(p.t20_bat_6s,0)         AS bat_6s,
      COALESCE(p.t20_bowl_matches,0)   AS bowl_matches,
      COALESCE(p.t20_bowl_wickets,0)   AS bowl_wickets,
      COALESCE(p.t20_bowl_economy,99)  AS bowl_economy,
      COALESCE(p.t20_bowl_5wi,0)       AS bowl_5wi,
      0                                AS bowl_10wi
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)

    UNION ALL

    SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0),   COALESCE(p.odi_bat_runs,0),
      COALESCE(p.odi_bat_avg,0),       COALESCE(p.odi_bat_strike_rate,0),
      COALESCE(p.odi_bat_50s,0),       COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0),        COALESCE(p.odi_bat_6s,0),
      COALESCE(p.odi_bowl_matches,0),  COALESCE(p.odi_bowl_wickets,0),
      COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)

    UNION ALL

    SELECT p.player_name, p.country, p.player_pool_source, r.role, 'test',
      COALESCE(p.test_bat_matches,0),   COALESCE(p.test_bat_runs,0),
      COALESCE(p.test_bat_avg,0),       COALESCE(p.test_bat_strike_rate,0),
      COALESCE(p.test_bat_50s,0),       COALESCE(p.test_bat_100s,0),
      COALESCE(p.test_bat_4s,0),        COALESCE(p.test_bat_6s,0),
      COALESCE(p.test_bowl_matches,0),  COALESCE(p.test_bowl_wickets,0),
      COALESCE(p.test_bowl_economy,99), COALESCE(p.test_bowl_5wi,0),
      COALESCE(p.test_bowl_10wi,0)
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)
  ),

  -- ── Normalize: percentile rank within (format, role) ─────
  normalized AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      bat_matches, bat_runs, bat_avg, bat_sr,
      bat_50s, bat_100s, bat_4s, bat_6s,
      bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,

      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_runs)                * 100)::numeric,1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_avg)                 * 100)::numeric,1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_sr)                  * 100)::numeric,1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_50s)                 * 100)::numeric,1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_100s)                * 100)::numeric,1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY (bat_4s + bat_6s*1.5))   * 100)::numeric,1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_6s)                  * 100)::numeric,1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bat_matches)             * 100)::numeric,1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_wickets)            * 100)::numeric,1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_economy))      * 100)::numeric,1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_5wi)                * 100)::numeric,1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_10wi)               * 100)::numeric,1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format,role ORDER BY bowl_matches)            * 100)::numeric,1) AS bowl_experience_score
    FROM unpivoted
  ),

  -- ── Score: calculate batting/bowling impact and budget ────
  scored AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      bat_matches, bat_runs, bat_avg, bat_sr,
      bat_50s, bat_100s, bat_4s, bat_6s,
      bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
      runs_score, batting_avg_score, strike_rate_score, fifties_score,
      hundreds_score, boundary_score, sixes_score, bat_experience_score,
      wickets_score, economy_score, five_wicket_score, ten_wicket_score,
      bowl_experience_score,

      -- Batting impact (format-specific weights)
      ROUND(CASE
        WHEN format='t20'  THEN runs_score*0.30 + strike_rate_score*0.30 + boundary_score*0.20 + sixes_score*0.20
        WHEN format='odi'  THEN runs_score*0.40 + batting_avg_score*0.30 + strike_rate_score*0.30
        WHEN format='test' THEN hundreds_score*0.40 + fifties_score*0.30 + runs_score*0.30
      END, 1) AS batting_impact_score,

      -- Bowling impact (format-specific weights)
      ROUND(CASE
        WHEN format='t20'  THEN wickets_score*0.50 + economy_score*0.50
        WHEN format='odi'  THEN wickets_score*0.55 + economy_score*0.45
        WHEN format='test' THEN wickets_score*0.40 + five_wicket_score*0.35 + ten_wicket_score*0.25
      END, 1) AS bowling_impact_score,

      -- Batting budget score (role-independent — used for budget valuation)
      ROUND(CASE
        WHEN format='t20'  THEN bat_experience_score*0.20 + batting_avg_score*0.30 + strike_rate_score*0.30 + fifties_score*0.20
        WHEN format='odi'  THEN bat_experience_score*0.20 + batting_avg_score*0.40 + fifties_score*0.20 + hundreds_score*0.20
        WHEN format='test' THEN bat_experience_score*0.20 + batting_avg_score*0.30 + fifties_score*0.25 + hundreds_score*0.25
      END, 1) AS batting_budget_score,

      -- Bowling budget score
      ROUND(CASE
        WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20 + wickets_score*0.40 + economy_score*0.40
        WHEN format='test'           THEN bowl_experience_score*0.20 + wickets_score*0.30 + five_wicket_score*0.25 + ten_wicket_score*0.25
      END, 1) AS bowling_budget_score
    FROM normalized
  ),

  -- ── Combine: final_impact_score and raw_budget_score ─────
  combined AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      bat_matches, bat_runs, bat_avg, bat_sr,
      bat_50s, bat_100s, bat_4s, bat_6s,
      bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
      runs_score, batting_avg_score, strike_rate_score, fifties_score,
      hundreds_score, boundary_score, sixes_score, bat_experience_score,
      wickets_score, economy_score, five_wicket_score, ten_wicket_score,
      bowl_experience_score,
      batting_impact_score, bowling_impact_score,
      batting_budget_score, bowling_budget_score,

      -- Final impact: role determines which dimension dominates
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role='batter'        THEN batting_impact_score
        WHEN role='wicket_keeper' THEN batting_impact_score
        WHEN role='bowler'        THEN bowling_impact_score
        WHEN role='all_rounder'   THEN batting_impact_score*0.50 + bowling_impact_score*0.50
        ELSE (batting_impact_score + bowling_impact_score) / 2
      END, 1))) AS final_impact_score,

      -- Raw budget: role determines which dimension dominates
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role='batter'        THEN batting_budget_score
        WHEN role='wicket_keeper' THEN batting_budget_score
        WHEN role='bowler'        THEN bowling_budget_score
        WHEN role='all_rounder'   THEN batting_budget_score*0.50 + bowling_budget_score*0.50
        ELSE (batting_budget_score + bowling_budget_score) / 2
      END, 1))) AS raw_budget_score
    FROM scored
  )

INSERT INTO player_format_scores (
  player_name, country, player_pool_source, role, format,
  bat_matches, bat_runs, bat_avg, bat_sr,
  bat_50s, bat_100s, bat_4s, bat_6s,
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
  bat_matches, bat_runs, bat_avg, bat_sr,
  bat_50s, bat_100s, bat_4s, bat_6s,
  bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,
  runs_score, batting_avg_score, strike_rate_score, fifties_score,
  hundreds_score, boundary_score, sixes_score, bat_experience_score,
  wickets_score, economy_score, five_wicket_score, ten_wicket_score,
  bowl_experience_score,
  batting_impact_score, bowling_impact_score, final_impact_score,
  batting_budget_score, bowling_budget_score, raw_budget_score,
  NOW(), NOW()
FROM combined;


-- ============================================================
-- STEP 3: VERIFY
-- ============================================================

-- Row count by format
SELECT format, COUNT(*) AS player_count
FROM player_format_scores
GROUP BY format
ORDER BY format;

-- Score distribution by format + role
SELECT
  format, role,
  COUNT(*)                                                                              AS players,
  ROUND(AVG(final_impact_score),1)                                                     AS avg_impact,
  ROUND(AVG(raw_budget_score),1)                                                       AS avg_budget_score,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1)  AS median_impact
FROM player_format_scores
GROUP BY format, role
ORDER BY format, role;
