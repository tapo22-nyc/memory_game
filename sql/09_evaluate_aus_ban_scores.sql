-- ============================================================
-- FILE: sql/09_evaluate_aus_ban_scores.sql
-- PURPOSE: Evaluate player impact and budget scores for the
--          AUS vs BAN series across T20, ODI, and Test.
--
-- SECTIONS:
--   A — Final match budgets (what users see)
--   B — Full score breakdown: all 13 percentile components
--   C — Raw stats vs computed scores side by side
--   D — Role + side assignment (explains premium selection)
--   E — Score anomaly flags (over/undervalued players)
--   F — Formula step-by-step for one player (debug tool)
--   G — Global percentile context (where AUS/BAN rank overall)
-- ============================================================


-- ============================================================
-- SECTION A: FINAL MATCH BUDGETS
-- What each player is priced at inside each match.
-- Change the match_title filter to see a specific format.
-- ============================================================

-- A1: All 3 matches — budget and tier overview
SELECT
  fm.match_title,
  fm.match_format,
  mpb.player_name,
  mpb.team_name                   AS country,
  mpb.role,
  mpb.budget_tier,
  '$' || TO_CHAR(mpb.final_player_budget, 'FM999,999') AS price,
  ROUND(mpb.raw_budget_score, 1)  AS raw_budget_score,
  ROUND(mpb.final_impact_score, 1)AS impact_score
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
ORDER BY fm.match_format, mpb.budget_tier, mpb.raw_budget_score DESC;


-- A2: Tier summary per match (should be premium=4, mid=8, value=10)
SELECT
  fm.match_title,
  fm.match_format,
  mpb.budget_tier,
  COUNT(*)                                    AS player_count,
  '$' || TO_CHAR(MIN(mpb.final_player_budget),'FM999,999') AS min_price,
  '$' || TO_CHAR(MAX(mpb.final_player_budget),'FM999,999') AS max_price,
  ROUND(AVG(mpb.raw_budget_score),1)          AS avg_budget_score
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
GROUP BY fm.match_title, fm.match_format, mpb.budget_tier
ORDER BY fm.match_format, mpb.budget_tier;


-- ============================================================
-- SECTION B: FULL PERCENTILE SCORE BREAKDOWN
-- Shows all 13 component percentile scores for each player.
-- Each score is 0–100 = percentile rank vs ALL players
-- in the same role+format group globally.
-- ============================================================

-- B1: T20 scores
SELECT
  pfs.player_name,
  pfs.country,
  pfs.role,
  -- Batting percentiles
  pfs.bat_experience_score  AS bat_exp,
  pfs.runs_score            AS runs,
  pfs.batting_avg_score     AS avg,
  pfs.strike_rate_score     AS sr,
  pfs.fifties_score         AS "50s",
  pfs.hundreds_score        AS "100s",
  pfs.boundary_score        AS bound,
  pfs.sixes_score           AS sixes,
  -- Bowling percentiles
  pfs.bowl_experience_score AS bowl_exp,
  pfs.wickets_score         AS wkts,
  pfs.economy_score         AS eco,
  pfs.five_wicket_score     AS "5wi",
  -- Composite scores
  pfs.batting_impact_score  AS bat_impact,
  pfs.bowling_impact_score  AS bowl_impact,
  pfs.final_impact_score    AS final_impact,
  pfs.batting_budget_score  AS bat_budget,
  pfs.bowling_budget_score  AS bowl_budget,
  pfs.raw_budget_score      AS raw_budget
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.format = 't20'
ORDER BY pfs.raw_budget_score DESC;


-- B2: ODI scores
SELECT
  pfs.player_name,
  pfs.country,
  pfs.role,
  pfs.bat_experience_score  AS bat_exp,
  pfs.runs_score            AS runs,
  pfs.batting_avg_score     AS avg,
  pfs.strike_rate_score     AS sr,
  pfs.fifties_score         AS "50s",
  pfs.hundreds_score        AS "100s",
  pfs.boundary_score        AS bound,
  pfs.sixes_score           AS sixes,
  pfs.bowl_experience_score AS bowl_exp,
  pfs.wickets_score         AS wkts,
  pfs.economy_score         AS eco,
  pfs.five_wicket_score     AS "5wi",
  pfs.batting_impact_score  AS bat_impact,
  pfs.bowling_impact_score  AS bowl_impact,
  pfs.final_impact_score    AS final_impact,
  pfs.batting_budget_score  AS bat_budget,
  pfs.bowling_budget_score  AS bowl_budget,
  pfs.raw_budget_score      AS raw_budget
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.format = 'odi'
ORDER BY pfs.raw_budget_score DESC;


-- B3: Test scores
SELECT
  pfs.player_name,
  pfs.country,
  pfs.role,
  pfs.bat_experience_score  AS bat_exp,
  pfs.runs_score            AS runs,
  pfs.batting_avg_score     AS avg,
  pfs.strike_rate_score     AS sr,
  pfs.fifties_score         AS "50s",
  pfs.hundreds_score        AS "100s",
  pfs.boundary_score        AS bound,
  pfs.sixes_score           AS sixes,
  pfs.bowl_experience_score AS bowl_exp,
  pfs.wickets_score         AS wkts,
  pfs.economy_score         AS eco,
  pfs.five_wicket_score     AS "5wi",
  pfs.ten_wicket_score      AS "10wi",
  pfs.batting_impact_score  AS bat_impact,
  pfs.bowling_impact_score  AS bowl_impact,
  pfs.final_impact_score    AS final_impact,
  pfs.batting_budget_score  AS bat_budget,
  pfs.bowling_budget_score  AS bowl_budget,
  pfs.raw_budget_score      AS raw_budget
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.format = 'test'
ORDER BY pfs.raw_budget_score DESC;


-- ============================================================
-- SECTION C: RAW STATS vs COMPUTED SCORES SIDE BY SIDE
-- Lets you spot where a score doesn't match the raw numbers.
-- ============================================================

-- C1: Batting-focused view (batters + WKs) — all formats
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.role,
  -- Raw batting stats
  pfs.bat_matches,
  pfs.bat_runs,
  ROUND(pfs.bat_avg, 2)    AS bat_avg,
  ROUND(pfs.bat_sr, 2)     AS bat_sr,
  pfs.bat_50s,
  pfs.bat_100s,
  -- What the formula made of those stats
  pfs.runs_score,
  pfs.batting_avg_score,
  pfs.strike_rate_score,
  pfs.fifties_score,
  pfs.hundreds_score,
  pfs.batting_impact_score AS bat_impact,
  pfs.batting_budget_score AS bat_budget_score
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.role IN ('batter','wicket_keeper')
ORDER BY pfs.format, pfs.bat_runs DESC;


-- C2: Bowling-focused view (bowlers + all-rounders) — all formats
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.role,
  -- Raw bowling stats
  pfs.bowl_matches,
  pfs.bowl_wickets,
  ROUND(pfs.bowl_economy, 2) AS bowl_economy,
  pfs.bowl_5wi,
  pfs.bowl_10wi,
  -- What the formula made of those stats
  pfs.wickets_score,
  pfs.economy_score,
  pfs.five_wicket_score,
  pfs.ten_wicket_score,
  pfs.bowling_impact_score AS bowl_impact,
  pfs.bowling_budget_score AS bowl_budget_score
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.role IN ('bowler','all_rounder')
ORDER BY pfs.format, pfs.bowl_wickets DESC;


-- C3: All-rounders split — shows batting vs bowling budget score
-- Used to determine which "side" they count toward for premium selection
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.bat_runs,
  ROUND(pfs.bat_avg,2)         AS bat_avg,
  ROUND(pfs.bat_sr,2)          AS bat_sr,
  pfs.bowl_wickets,
  ROUND(pfs.bowl_economy,2)    AS bowl_eco,
  pfs.batting_budget_score,
  pfs.bowling_budget_score,
  pfs.raw_budget_score,
  CASE
    WHEN pfs.batting_budget_score >= pfs.bowling_budget_score THEN 'batting side'
    ELSE 'bowling side'
  END AS premium_side
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.role = 'all_rounder'
ORDER BY pfs.format, pfs.raw_budget_score DESC;


-- ============================================================
-- SECTION D: ROLE + SIDE ASSIGNMENT PER MATCH
-- Shows who got premium, which side they counted toward,
-- and the side_rank that determined premium eligibility.
-- ============================================================

SELECT
  fm.match_format,
  mpb.player_name,
  mpb.team_name                 AS country,
  mpb.role,
  CASE
    WHEN mpb.role IN ('batter','wicket_keeper') THEN 'batting'
    WHEN mpb.role = 'bowler' THEN 'bowling'
    WHEN mpb.role = 'all_rounder' THEN
      CASE WHEN pfs.batting_budget_score >= pfs.bowling_budget_score THEN 'batting'
           ELSE 'bowling' END
    ELSE 'batting'
  END                           AS side,
  mpb.budget_tier,
  ROUND(mpb.raw_budget_score,1) AS raw_budget_score,
  ROUND(pfs.batting_budget_score,1) AS bat_bgt_score,
  ROUND(pfs.bowling_budget_score,1) AS bowl_bgt_score,
  '$' || TO_CHAR(mpb.final_player_budget,'FM999,999') AS final_price
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
LEFT JOIN player_format_scores pfs
  ON  LOWER(pfs.player_name) = LOWER(mpb.player_name)
  AND pfs.format = fm.match_format
  AND pfs.country = mpb.team_name
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
ORDER BY fm.match_format, mpb.budget_tier, mpb.raw_budget_score DESC;


-- ============================================================
-- SECTION E: ANOMALY FLAGS
-- Highlights players whose scores look suspicious.
-- ============================================================

-- E1: Players defaulted to score=50 (name mismatch — not found in player_format_scores)
SELECT
  fm.match_format,
  mpb.player_name,
  mpb.team_name,
  mpb.role,
  mpb.raw_budget_score,
  mpb.budget_tier,
  '$' || TO_CHAR(mpb.final_player_budget,'FM999,999') AS price,
  'Score defaulted to 50 — name not matched in player_format_scores' AS flag
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
  AND mpb.raw_budget_score = 50
ORDER BY fm.match_format, mpb.player_name;


-- E2: Players with very low scores (may indicate 0-stat rows used)
-- These will show as value tier but may be genuinely inexperienced
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.role,
  pfs.bat_matches,
  pfs.bowl_matches,
  pfs.raw_budget_score,
  pfs.final_impact_score,
  CASE
    WHEN pfs.bat_matches = 0 AND pfs.bowl_matches = 0 THEN 'No matches in this format'
    WHEN pfs.bat_matches < 5 AND pfs.role IN ('batter','wicket_keeper') THEN 'Very few batting matches'
    WHEN pfs.bowl_matches < 5 AND pfs.role IN ('bowler') THEN 'Very few bowling matches'
    ELSE 'Low score but has data'
  END AS note
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.raw_budget_score < 25
ORDER BY pfs.format, pfs.raw_budget_score;


-- E3: Score vs expectation — batters with high runs but low budget score
-- (can reveal calibration issues)
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.bat_runs,
  ROUND(pfs.bat_avg,2)          AS bat_avg,
  pfs.batting_impact_score,
  pfs.batting_budget_score,
  pfs.raw_budget_score,
  '$' || TO_CHAR(mpb.final_player_budget,'FM999,999') AS final_price,
  mpb.budget_tier
FROM player_format_scores pfs
JOIN match_player_budgets mpb ON LOWER(mpb.player_name) = LOWER(pfs.player_name)
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id AND fm.match_format = pfs.format
WHERE pfs.country IN ('AUS','BAN')
  AND pfs.role IN ('batter','wicket_keeper')
  AND fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
  AND pfs.bat_runs > 500
  AND pfs.raw_budget_score < 40
ORDER BY pfs.format, pfs.bat_runs DESC;


-- ============================================================
-- SECTION F: STEP-BY-STEP FORMULA DEBUG FOR ONE PLAYER
-- Change player_name and format below to inspect any player.
-- Shows every input and intermediate calculation.
-- ============================================================

-- ← Change these two values:
-- player: 'Adam Zampa'   format: 't20'

WITH target AS (
  SELECT
    pfs.*,
    -- Reproduce the formula steps
    -- T20 batting impact = runs*0.30 + sr*0.30 + boundary*0.20 + sixes*0.20
    -- ODI batting impact = runs*0.40 + avg*0.30 + sr*0.30
    -- Test batting impact = hundreds*0.40 + fifties*0.30 + runs*0.30
    ROUND(CASE
      WHEN pfs.format='t20'  THEN pfs.runs_score*0.30 + pfs.strike_rate_score*0.30 + pfs.boundary_score*0.20 + pfs.sixes_score*0.20
      WHEN pfs.format='odi'  THEN pfs.runs_score*0.40 + pfs.batting_avg_score*0.30 + pfs.strike_rate_score*0.30
      WHEN pfs.format='test' THEN pfs.hundreds_score*0.40 + pfs.fifties_score*0.30 + pfs.runs_score*0.30
    END, 1) AS calc_bat_impact,
    ROUND(CASE
      WHEN pfs.format='t20'  THEN pfs.wickets_score*0.50 + pfs.economy_score*0.50
      WHEN pfs.format='odi'  THEN pfs.wickets_score*0.55 + pfs.economy_score*0.45
      WHEN pfs.format='test' THEN pfs.wickets_score*0.40 + pfs.five_wicket_score*0.35 + pfs.ten_wicket_score*0.25
    END, 1) AS calc_bowl_impact,
    -- T20 bat budget = exp*0.20 + avg*0.30 + sr*0.30 + 50s*0.20
    ROUND(CASE
      WHEN pfs.format='t20'  THEN pfs.bat_experience_score*0.20 + pfs.batting_avg_score*0.30 + pfs.strike_rate_score*0.30 + pfs.fifties_score*0.20
      WHEN pfs.format='odi'  THEN pfs.bat_experience_score*0.20 + pfs.batting_avg_score*0.40 + pfs.fifties_score*0.20 + pfs.hundreds_score*0.20
      WHEN pfs.format='test' THEN pfs.bat_experience_score*0.20 + pfs.batting_avg_score*0.30 + pfs.fifties_score*0.25 + pfs.hundreds_score*0.25
    END, 1) AS calc_bat_budget,
    ROUND(CASE
      WHEN pfs.format IN ('t20','odi') THEN pfs.bowl_experience_score*0.20 + pfs.wickets_score*0.40 + pfs.economy_score*0.40
      WHEN pfs.format='test'           THEN pfs.bowl_experience_score*0.20 + pfs.wickets_score*0.30 + pfs.five_wicket_score*0.25 + pfs.ten_wicket_score*0.25
    END, 1) AS calc_bowl_budget
  FROM player_format_scores pfs
  WHERE LOWER(pfs.player_name) = LOWER('Adam Zampa')   -- ← change player name
    AND pfs.format = 't20'                               -- ← change format
)
SELECT
  player_name, country, role, format,
  '--- RAW STATS ---'          AS section1,
  bat_matches, bat_runs,
  ROUND(bat_avg,2) AS bat_avg, ROUND(bat_sr,2) AS bat_sr,
  bat_50s, bat_100s,
  bowl_matches, bowl_wickets,
  ROUND(bowl_economy,2) AS bowl_eco, bowl_5wi, bowl_10wi,
  '--- PERCENTILE SCORES ---'  AS section2,
  bat_experience_score, runs_score, batting_avg_score, strike_rate_score,
  fifties_score, hundreds_score, boundary_score, sixes_score,
  bowl_experience_score, wickets_score, economy_score,
  five_wicket_score, ten_wicket_score,
  '--- COMPOSITE SCORES ---'   AS section3,
  batting_impact_score, calc_bat_impact    AS recalc_bat_impact,
  bowling_impact_score, calc_bowl_impact   AS recalc_bowl_impact,
  final_impact_score,
  '--- BUDGET SCORES ---'      AS section4,
  batting_budget_score, calc_bat_budget    AS recalc_bat_budget,
  bowling_budget_score, calc_bowl_budget   AS recalc_bowl_budget,
  raw_budget_score
FROM target;


-- ============================================================
-- SECTION G: GLOBAL PERCENTILE CONTEXT
-- Shows where AUS/BAN players rank among ALL players in the DB,
-- not just against each other. This is the real percentile basis.
-- A score of 70 means the player beats 70% of ALL players
-- in that role+format globally.
-- ============================================================

-- G1: Global rank of AUS/BAN players within their role+format group
SELECT
  pfs.format,
  pfs.player_name,
  pfs.country,
  pfs.role,
  pfs.raw_budget_score,
  pfs.final_impact_score,
  -- Global rank within role+format
  RANK() OVER (
    PARTITION BY pfs.format, pfs.role
    ORDER BY pfs.raw_budget_score DESC
  ) AS global_rank,
  COUNT(*) OVER (
    PARTITION BY pfs.format, pfs.role
  ) AS total_in_group,
  ROUND(
    100.0 * (1 - RANK() OVER (
      PARTITION BY pfs.format, pfs.role
      ORDER BY pfs.raw_budget_score DESC
    )::NUMERIC / NULLIF(COUNT(*) OVER (PARTITION BY pfs.format, pfs.role), 0))
  , 0) AS top_pct
FROM player_format_scores pfs
WHERE pfs.country IN ('AUS','BAN')
ORDER BY pfs.format, pfs.role, pfs.raw_budget_score DESC;


-- G2: How many players are in each scoring group globally
-- (context for why percentile scores look the way they do)
SELECT
  format,
  role,
  COUNT(*)                               AS total_players,
  ROUND(AVG(raw_budget_score),1)         AS avg_budget_score,
  ROUND(AVG(final_impact_score),1)       AS avg_impact,
  MIN(raw_budget_score)                  AS min_score,
  MAX(raw_budget_score)                  AS max_score
FROM player_format_scores
GROUP BY format, role
ORDER BY format, role;
