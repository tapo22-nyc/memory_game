-- ============================================================
-- FILE: sql/13_ind_afg_1st_odi_manual_scoring.sql
-- PURPOSE: Manual score entry fallback for Match 84
--          IND vs AFG — 1st ODI (2026-06-13)
-- USE WHEN: CricAPI sync fails / players unmapped / match done
--
-- HOW TO USE:
--   1. Open the scorecard on Cricbuzz or ESPNcricinfo
--   2. Fill in stats for every player who played (batted/bowled/fielded)
--      — Players who did NOT play at all: leave them out (0 fantasy pts)
--   3. Run SECTION A (raw stats INSERT)
--   4. Run SECTION B (fantasy_points calculation UPDATE)
--   5. Open in browser: https://playmtgames.com/api/recalculate-fantasy-user-scores?fantasy_match_id=84
--   6. Run SECTION C to verify
--
-- COLUMN GUIDE:
--   runs          → Runs scored with the bat
--   balls_faced   → Balls faced while batting (0 if didn't bat)
--   fours         → Number of 4s hit
--   sixes         → Number of 6s hit
--   strike_rate   → runs/balls_faced * 100  (enter 0 if didn't bat)
--   overs_bowled  → Overs bowled, e.g. 10.0 = 10 overs, 9.4 = 9 overs 4 balls
--   maidens       → Maiden overs
--   runs_conceded → Runs given away while bowling
--   wickets       → Wickets taken
--   no_balls      → No-balls bowled
--   wides         → Wides bowled
--   economy_rate  → runs_conceded / overs_bowled  (enter 0 if didn't bowl)
--   catches       → Catches taken (includes non-bowling fielding)
--   stumpings     → Stumpings (WK only)
--   runouts       → Run-outs effected (direct hit or relay throw)
-- ============================================================


-- ============================================================
-- SCORING RULES REFERENCE (what each stat is worth)
-- ============================================================
--  Run scored           → 1 pt each
--  Four hit             → 4 pts each  (on top of run points)
--  Six hit              → 6 pts each  (on top of run points)
--  Strike rate ≥ 150    → +10 pts  (only if faced ≥ 10 balls)
--  Strike rate > 200    → +20 pts  (only if faced ≥ 10 balls)
--  Wicket taken         → 25 pts each
--  Maiden over          → 15 pts each
--  Economy ≤ 5.00       → +20 pts  (only if bowled ≥ 2 overs)
--  Economy 5.01–7.00    → +10 pts
--  Economy 7.01–9.00    → +5 pts
--  Economy 9.01–10.99   → -5 pts
--  Economy ≥ 11.00      → -10 pts
--  Catch                → 8 pts each
--  Stumping             → 12 pts each
--  Run-out              → 12 pts each
-- ============================================================


-- ============================================================
-- SECTION A: INSERT / UPDATE RAW PLAYER STATS
-- Fill in the numbers from the scorecard.
-- Safe to re-run — uses ON CONFLICT DO UPDATE.
-- Only include players who actually played.
-- ============================================================

INSERT INTO fantasy_player_match_stats (
  fantasy_match_id, player_id,
  runs, balls_faced, fours, sixes, strike_rate,
  overs_bowled, maidens, runs_conceded, wickets, no_balls, wides, economy_rate,
  catches, stumpings, runouts
)
VALUES

  -- ================================================================
  -- INDIA — fill in stats from scorecard
  -- ================================================================

  -- Shubman Gill
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shubman Gill'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,   -- runs, balls, 4s, 6s, SR
   0.0, 0, 0, 0, 0, 0, 0.0,   -- overs, maidens, runs_conceded, wkts, nb, wd, eco
   0, 0, 0),              -- catches, stumpings, runouts

  -- Rohit Sharma
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rohit Sharma'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Yashasvi Jaiswal
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Yashasvi Jaiswal'   AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Shreyas Iyer
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shreyas Iyer'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- KL Rahul (WK)
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'KL Rahul'           AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Ishan Kishan (WK)
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ishan Kishan'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Washington Sundar
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Washington Sundar'  AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Nitish Kumar Reddy
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nitish Kumar Reddy' AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Kuldeep Yadav
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Kuldeep Yadav'      AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Arshdeep Singh
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Arshdeep Singh'     AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Gurnoon Brar
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Gurnoon Brar'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Prasidh Krishna
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prasidh Krishna'    AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Prince Yadav
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prince Yadav'       AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Harsh Yadav
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Harsh Yadav'        AND country = 'IND'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- ================================================================
  -- AFGHANISTAN — fill in stats from scorecard
  -- ================================================================

  -- Rahmanullah Gurbaz (WK)
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmanullah Gurbaz'  AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Ibrahim Zadran
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ibrahim Zadran'      AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Rahmat Shah
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmat Shah'         AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Hashmatullah Shahid
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Hashmatullah Shahid' AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Sediqullah Atal
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Sediqullah Atal'     AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Darwish Rasooli
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Darwish Rasooli'     AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Ikram Alikhil (WK)
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ikram Alikhil'       AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Azmatullah Omarzai
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Azmatullah Omarzai'  AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Mohammad Nabi
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Mohammad Nabi'       AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Rashid Khan
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rashid Khan'         AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Nangeyalia Kharoti
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nangeyalia Kharoti'  AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- AM Ghazanfar
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'AM Ghazanfar'        AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Bilal Sami
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Bilal Sami'          AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0),

  -- Fareed Ahmad Malik
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Fareed Ahmad Malik'  AND country = 'AFG'),
   0,  0,  0, 0, 0.0,
   0.0, 0, 0, 0, 0, 0, 0.0,
   0, 0, 0)

ON CONFLICT (fantasy_match_id, player_id) DO UPDATE SET
  runs           = EXCLUDED.runs,
  balls_faced    = EXCLUDED.balls_faced,
  fours          = EXCLUDED.fours,
  sixes          = EXCLUDED.sixes,
  strike_rate    = EXCLUDED.strike_rate,
  overs_bowled   = EXCLUDED.overs_bowled,
  maidens        = EXCLUDED.maidens,
  runs_conceded  = EXCLUDED.runs_conceded,
  wickets        = EXCLUDED.wickets,
  no_balls       = EXCLUDED.no_balls,
  wides          = EXCLUDED.wides,
  economy_rate   = EXCLUDED.economy_rate,
  catches        = EXCLUDED.catches,
  stumpings      = EXCLUDED.stumpings,
  runouts        = EXCLUDED.runouts,
  updated_at     = CURRENT_TIMESTAMP;


-- ============================================================
-- SECTION B: CALCULATE FANTASY POINTS
-- Run this immediately after Section A.
-- This is the exact same formula the CricAPI sync uses.
-- ============================================================

UPDATE fantasy_player_match_stats s
SET fantasy_points =
    s.runs * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'RUN'  AND is_active = TRUE), 1)
  + s.fours * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'FOUR' AND is_active = TRUE), 4)
  + s.sixes * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SIX'  AND is_active = TRUE), 6)

  + CASE
      WHEN s.balls_faced >= 10 AND s.strike_rate > 200
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SR_ABOVE_200' AND is_active = TRUE), 20)
      WHEN s.balls_faced >= 10 AND s.strike_rate >= 150 AND s.strike_rate <= 200
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SR_150_200'   AND is_active = TRUE), 10)
      ELSE 0
    END

  + s.wickets * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'WICKET'  AND is_active = TRUE), 25)
  + s.maidens * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'MAIDEN'  AND is_active = TRUE), 15)

  + CASE
      WHEN s.overs_bowled >= 2 AND s.economy_rate <= 5
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_LE_5'  AND is_active = TRUE), 20)
      WHEN s.overs_bowled >= 2 AND s.economy_rate > 5  AND s.economy_rate <= 7
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_5_7'   AND is_active = TRUE), 10)
      WHEN s.overs_bowled >= 2 AND s.economy_rate > 7  AND s.economy_rate <= 9
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_7_9'   AND is_active = TRUE), 5)
      WHEN s.overs_bowled >= 2 AND s.economy_rate > 9  AND s.economy_rate < 11
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_9_11'  AND is_active = TRUE), -5)
      WHEN s.overs_bowled >= 2 AND s.economy_rate >= 11
        THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_GE_11' AND is_active = TRUE), -10)
      ELSE 0
    END

  + s.catches   * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'CATCH'    AND is_active = TRUE), 8)
  + s.stumpings * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'STUMPING' AND is_active = TRUE), 12)
  + s.runouts   * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'RUNOUT'   AND is_active = TRUE), 12)

WHERE s.fantasy_match_id = 84;


-- ============================================================
-- After Section B, open this URL in your browser to push
-- scores into user teams (applies captain ×2 / VC ×1.5):
--   https://playmtgames.com/api/recalculate-fantasy-user-scores?fantasy_match_id=84
-- ============================================================


-- ============================================================
-- SECTION C: VERIFY
-- ============================================================

-- C1: Player scores — sorted by fantasy points
SELECT
  cpp.player_name,
  cpp.country,
  s.runs,
  s.balls_faced,
  s.fours,
  s.sixes,
  ROUND(s.strike_rate, 1)   AS sr,
  s.overs_bowled,
  s.wickets,
  ROUND(s.economy_rate, 2)  AS eco,
  s.catches,
  s.stumpings,
  s.runouts,
  s.fantasy_points
FROM fantasy_player_match_stats s
JOIN cricket_player_pool cpp ON cpp.id = s.player_id
WHERE s.fantasy_match_id = 84
ORDER BY s.fantasy_points DESC;

-- C2: User leaderboard
SELECT
  fums.user_id,
  fums.total_fantasy_points,
  fums.rank
FROM fantasy_user_match_scores fums
WHERE fums.fantasy_match_id = 84
ORDER BY fums.total_fantasy_points DESC;

-- C3: Quick sanity — any player with non-zero stats but 0 points?
SELECT
  cpp.player_name,
  s.runs, s.wickets, s.catches, s.fantasy_points
FROM fantasy_player_match_stats s
JOIN cricket_player_pool cpp ON cpp.id = s.player_id
WHERE s.fantasy_match_id = 84
  AND s.fantasy_points = 0
  AND (s.runs > 0 OR s.wickets > 0 OR s.catches > 0)
ORDER BY cpp.player_name;
