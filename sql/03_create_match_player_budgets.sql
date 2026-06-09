-- ============================================================
-- FILE: sql/03_create_match_player_budgets.sql
-- PURPOSE: Create match_player_budgets — final player budget
--          per fantasy match, calculated ONLY within the 24
--          active players of that specific match.
--
-- KEY CONCEPT:
--   raw_budget_score comes from player_format_scores (global).
--   But the TIER and FINAL DOLLAR AMOUNT are calculated
--   relative to the other 23 players in the same match.
--   A player can be premium in one match and mid in another.
--
-- TIER LOGIC PER MATCH (24 active players assumed):
--   Premium (4 players):  top 2 batting-side + top 2 bowling-side
--                         by raw_budget_score → $200K–$250K
--   Mid     (8 players):  next 8 by raw_budget_score           → $120K–$190K
--   Value   (12 players): remaining 12                         → $50K–$120K
--
-- BATTING SIDE:  batter, wicket_keeper, batting-heavy all_rounder
-- BOWLING SIDE:  bowler, bowling-heavy all_rounder
-- ALL_ROUNDER SIDE: batting_budget_score >= bowling_budget_score → batting
--
-- WITHIN-TIER BUDGET:
--   Scaled linearly from tier floor to tier ceiling using each
--   player's raw_budget_score relative to the tier's min/max.
--   Rounded to nearest $5,000. Clamped to tier range.
--
-- PREREQUISITE: Run FILE 2 first so player_format_scores exists.
--
-- WHAT THIS DOES:
--   Step 1 — CREATE TABLE match_player_budgets
--   Step 2 — POPULATE for all open matches (main operation)
--   Step 3 — POPULATE for a single match (use for new matches)
--   Step 4 — Verify
--
-- SAFE TO RE-RUN: all writes use ON CONFLICT DO UPDATE.
-- ============================================================


-- ============================================================
-- STEP 1: CREATE TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS match_player_budgets (

  id                    SERIAL PRIMARY KEY,

  -- ── Match + player key ────────────────────────────────────
  fantasy_match_id      INTEGER       NOT NULL,
  player_id             INTEGER       NOT NULL,
  player_source         TEXT          NOT NULL DEFAULT 'ipl',  -- 'ipl' or 'cricket'

  -- ── Player info (denormalized for fast reads) ─────────────
  player_name           TEXT,
  team_name             TEXT,
  role                  TEXT,          -- 'batter','bowler','all_rounder','wicket_keeper','unknown'
  format                TEXT,          -- 't20','odi','test'

  -- ── Scores from player_format_scores ─────────────────────
  final_impact_score    NUMERIC(5,1),
  raw_budget_score      NUMERIC(5,1),
  batting_budget_score  NUMERIC(5,1),  -- stored for debugging / all_rounder side logic
  bowling_budget_score  NUMERIC(5,1),

  -- ── Match-level budget output ─────────────────────────────
  budget_tier           TEXT          NOT NULL DEFAULT 'value',  -- 'premium','mid','value'
  final_player_budget   INTEGER       NOT NULL DEFAULT 50000,    -- in USD cents-free: 50000 = $50K

  -- ── Metadata ─────────────────────────────────────────────
  created_at            TIMESTAMP     DEFAULT NOW(),
  updated_at            TIMESTAMP     DEFAULT NOW(),

  UNIQUE (fantasy_match_id, player_id, player_source)
);

CREATE INDEX IF NOT EXISTS idx_mpb_match
  ON match_player_budgets (fantasy_match_id);

CREATE INDEX IF NOT EXISTS idx_mpb_player
  ON match_player_budgets (player_id, player_source);

CREATE INDEX IF NOT EXISTS idx_mpb_tier
  ON match_player_budgets (fantasy_match_id, budget_tier);


-- ============================================================
-- STEP 2: POPULATE FOR ALL OPEN MATCHES
--
-- Calculates and upserts budgets for every active player in
-- every fantasy match that has status = 'open'.
--
-- To process ALL matches instead (including locked/closed),
-- remove the "AND fm.status = 'open'" filter below.
-- ============================================================

WITH

  -- All active players in open matches with format mapping
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
      END                                               AS score_format
    FROM fantasy_match_players fmp
    JOIN fantasy_matches fm ON fm.id = fmp.fantasy_match_id
    LEFT JOIN ipl_player_master ipm
      ON  ipm.id = fmp.player_id
      AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
    LEFT JOIN cricket_player_pool cpp
      ON  cpp.id = fmp.player_id
      AND fmp.player_source = 'cricket'
    WHERE COALESCE(fmp.is_active, TRUE) = TRUE
      AND fm.status = 'open'   -- remove this line to include all matches
  ),

  -- Join to global format scores (name-based match, same as existing system)
  with_scores AS (
    SELECT
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
  ),

  -- Assign batting/bowling side for each player
  -- All_rounders: batting side if batting_budget_score >= bowling_budget_score
  with_side AS (
    SELECT *,
      CASE
        WHEN role IN ('batter', 'wicket_keeper') THEN 'batting'
        WHEN role = 'bowler'                     THEN 'bowling'
        WHEN role = 'all_rounder'                THEN
          CASE WHEN batting_budget_score >= bowling_budget_score
               THEN 'batting' ELSE 'bowling' END
        ELSE 'batting'  -- unknown defaults to batting side
      END AS side
    FROM with_scores
  ),

  -- Rank within batting/bowling side per match (for premium assignment)
  -- Top 2 batting-side + top 2 bowling-side = exactly 4 premium players
  ranked AS (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY fantasy_match_id, side
        ORDER BY raw_budget_score DESC, player_id
      ) AS side_rank
    FROM with_side
  ),

  -- Mark premium: side_rank <= 2 means top 2 in their batting or bowling group
  premium_flagged AS (
    SELECT *,
      CASE WHEN side_rank <= 2 THEN TRUE ELSE FALSE END AS is_premium
    FROM ranked
  ),

  -- Within the non-premium group (20 players), rank 1–20.
  -- rank_within_group 1–8 → mid, 9–20 → value
  tiered AS (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY fantasy_match_id, is_premium
        ORDER BY raw_budget_score DESC, player_id
      ) AS rank_within_group
    FROM premium_flagged
  ),

  -- Assign final tier label
  tier_assigned AS (
    SELECT *,
      CASE
        WHEN is_premium             THEN 'premium'
        WHEN rank_within_group <= 8 THEN 'mid'
        ELSE                             'value'
      END AS budget_tier
    FROM tiered
  ),

  -- Calculate min/max raw_budget_score within each tier per match
  -- Used for within-tier linear scaling
  tier_bounds AS (
    SELECT
      fantasy_match_id,
      budget_tier,
      MIN(raw_budget_score) AS tier_score_min,
      MAX(raw_budget_score) AS tier_score_max
    FROM tier_assigned
    GROUP BY fantasy_match_id, budget_tier
  ),

  -- Calculate final player budget:
  --   floor + (score_position_in_tier / tier_score_range) * tier_dollar_range
  --   rounded to nearest $5,000, clamped to tier [floor, ceiling]
  -- If all players in a tier have the same score, give each the tier midpoint.
  budgeted AS (
    SELECT
      ta.fantasy_match_id,
      ta.player_id,
      ta.player_source,
      ta.player_name,
      ta.team_name,
      ta.role,
      ta.score_format                   AS format,
      ta.final_impact_score,
      ta.raw_budget_score,
      ta.batting_budget_score,
      ta.bowling_budget_score,
      ta.budget_tier,
      GREATEST(
        CASE ta.budget_tier WHEN 'premium' THEN 200000 WHEN 'mid' THEN 120000 ELSE 50000 END,
        LEAST(
          CASE ta.budget_tier WHEN 'premium' THEN 250000 WHEN 'mid' THEN 190000 ELSE 120000 END,
          (ROUND(
            (
              -- tier floor
              CASE ta.budget_tier WHEN 'premium' THEN 200000 WHEN 'mid' THEN 120000 ELSE 50000 END
              +
              CASE
                -- all players in tier have same score → give each the midpoint
                WHEN tb.tier_score_max = tb.tier_score_min THEN
                  CASE ta.budget_tier WHEN 'premium' THEN 25000 WHEN 'mid' THEN 35000 ELSE 35000 END
                -- scale linearly within tier based on score position
                ELSE
                  (ta.raw_budget_score - tb.tier_score_min)::NUMERIC
                  / NULLIF(tb.tier_score_max - tb.tier_score_min, 0)
                  * CASE ta.budget_tier WHEN 'premium' THEN 50000 WHEN 'mid' THEN 70000 ELSE 70000 END
              END
            ) / 5000.0
          ) * 5000)::INTEGER
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
  budget_tier, final_player_budget,
  created_at, updated_at
)
SELECT
  fantasy_match_id, player_id, player_source, player_name, team_name,
  role, format, final_impact_score, raw_budget_score,
  batting_budget_score, bowling_budget_score,
  budget_tier, final_player_budget,
  NOW(), NOW()
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
  updated_at           = NOW();


-- ============================================================
-- STEP 3: POPULATE FOR A SINGLE MATCH
--
-- Use this after creating a new match.
-- Replace fantasy_match_id = 1 with the actual match ID.
-- ============================================================

/*
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
    WHERE fmp.fantasy_match_id = 1             -- ← replace with your match ID
      AND COALESCE(fmp.is_active, TRUE) = TRUE
  ),
  with_scores AS (
    SELECT ap.*,
      COALESCE(pfs.role,                 'unknown') AS role,
      COALESCE(pfs.final_impact_score,   50.0)      AS final_impact_score,
      COALESCE(pfs.raw_budget_score,     50.0)      AS raw_budget_score,
      COALESCE(pfs.batting_budget_score, 50.0)      AS batting_budget_score,
      COALESCE(pfs.bowling_budget_score, 50.0)      AS bowling_budget_score
    FROM active_players ap
    LEFT JOIN player_format_scores pfs
      ON  LOWER(pfs.player_name) = LOWER(ap.player_name)
      AND pfs.format = ap.score_format
  ),
  with_side AS (
    SELECT *,
      CASE
        WHEN role IN ('batter','wicket_keeper') THEN 'batting'
        WHEN role = 'bowler'                    THEN 'bowling'
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
    SELECT *, CASE WHEN side_rank <= 2 THEN TRUE ELSE FALSE END AS is_premium FROM ranked
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
      CASE WHEN is_premium THEN 'premium' WHEN rank_within_group <= 8 THEN 'mid' ELSE 'value' END AS budget_tier
    FROM tiered
  ),
  tier_bounds AS (
    SELECT fantasy_match_id, budget_tier,
      MIN(raw_budget_score) AS tier_score_min,
      MAX(raw_budget_score) AS tier_score_max
    FROM tier_assigned GROUP BY fantasy_match_id, budget_tier
  ),
  budgeted AS (
    SELECT ta.*,
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
    JOIN tier_bounds tb ON tb.fantasy_match_id = ta.fantasy_match_id AND tb.budget_tier = ta.budget_tier
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
  role=EXCLUDED.role, format=EXCLUDED.format,
  final_impact_score=EXCLUDED.final_impact_score,
  raw_budget_score=EXCLUDED.raw_budget_score,
  budget_tier=EXCLUDED.budget_tier,
  final_player_budget=EXCLUDED.final_player_budget,
  updated_at=NOW();
*/


-- ============================================================
-- STEP 4: VERIFY COUNTS
-- ============================================================

SELECT
  mpb.fantasy_match_id,
  fm.match_title,
  fm.match_format,
  COUNT(*) AS total_players,
  COUNT(*) FILTER (WHERE mpb.budget_tier = 'premium') AS premium_count,
  COUNT(*) FILTER (WHERE mpb.budget_tier = 'mid')     AS mid_count,
  COUNT(*) FILTER (WHERE mpb.budget_tier = 'value')   AS value_count,
  MIN(mpb.final_player_budget)                        AS min_budget,
  MAX(mpb.final_player_budget)                        AS max_budget
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
GROUP BY mpb.fantasy_match_id, fm.match_title, fm.match_format
ORDER BY mpb.fantasy_match_id;
