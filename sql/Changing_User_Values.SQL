-- ============================================================
-- FILE: sql/Changing_User_Values.SQL
-- PURPOSE: Update predicted_value entries in closest_call_predictions
--          for test users kartik15 and knicksrulz_17
--          across all 3 WWC 2026 test matches.
--
-- MATCHES COVERED:
--   W1: ENG-W vs WI-W   — 24 June 2026
--   W2: IND-W vs BAN-W  — 25 June 2026
--   W3: ENG-W vs NZ-W   — 27 June 2026
--
-- QUESTION TYPES PER MATCH (6 questions):
--   team_final_score  + team_code = Team 1  → Team 1 Final Score
--   team_final_score  + team_code = Team 2  → Team 2 Final Score
--   team_score_6      + team_code = Team 1  → Team 1 Powerplay Score
--   team_score_6      + team_code = Team 2  → Team 2 Powerplay Score
--   total_sixes       + team_code = Team 1  → Team 1 Sixes
--   total_sixes       + team_code = Team 2  → Team 2 Sixes
--
-- HOW TO USE:
--   1. Run the CURRENT VALUES query at the top to see existing predictions.
--   2. Edit the numeric values in the UPDATE blocks below.
--   3. Run the UPDATE blocks for the user(s) and match(es) you want to change.
--   4. Run the POST-UPDATE VERIFICATION query at the bottom to confirm.
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- ============================================================


-- ============================================================
-- STEP 0: VIEW CURRENT PREDICTED VALUES
-- Run this first to see what values are currently stored.
-- ============================================================

SELECT
  u.user_name,
  m.match_title,
  q.question_type,
  q.team_code,
  q.innings_number,
  p.predicted_value
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('kartik15', 'knicksrulz_17')
  AND  m.match_title IN (
         'ENG-W vs WI-W — WT20 WC 2026',
         'IND-W vs BAN-W — WT20 WC 2026',
         'ENG-W vs NZ-W — WT20 WC 2026'
       )
ORDER  BY u.user_name, m.match_date, q.innings_number, q.question_type;


-- ============================================================
-- ══ kartik15 — MATCH W1: ENG-W vs WI-W ══
-- Current values: ENG-W Final=152, WI-W Final=148,
--                 ENG-W PP=55,    WI-W PP=48,
--                 ENG-W Sixes=7,  WI-W Sixes=6
-- ============================================================

-- kartik15 · W1 · ENG-W Final Score  ← change 152 to new value
UPDATE closest_call_predictions
SET    predicted_value = 152           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W1 · WI-W Final Score  ← change 148 to new value
UPDATE closest_call_predictions
SET    predicted_value = 148           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'WI-W'
       );

-- kartik15 · W1 · ENG-W Powerplay  ← change 55 to new value
UPDATE closest_call_predictions
SET    predicted_value = 55            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W1 · WI-W Powerplay  ← change 48 to new value
UPDATE closest_call_predictions
SET    predicted_value = 48            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'WI-W'
       );

-- kartik15 · W1 · ENG-W Sixes  ← change 7 to new value
UPDATE closest_call_predictions
SET    predicted_value = 7             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W1 · WI-W Sixes  ← change 6 to new value
UPDATE closest_call_predictions
SET    predicted_value = 6             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'WI-W'
       );


-- ============================================================
-- ══ kartik15 — MATCH W2: IND-W vs BAN-W ══
-- Current values: IND-W Final=165, BAN-W Final=110,
--                 IND-W PP=62,    BAN-W PP=38,
--                 IND-W Sixes=9,  BAN-W Sixes=3
-- ============================================================

-- kartik15 · W2 · IND-W Final Score  ← change 165 to new value
UPDATE closest_call_predictions
SET    predicted_value = 165           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'IND-W'
       );

-- kartik15 · W2 · BAN-W Final Score  ← change 110 to new value
UPDATE closest_call_predictions
SET    predicted_value = 110           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'BAN-W'
       );

-- kartik15 · W2 · IND-W Powerplay  ← change 62 to new value
UPDATE closest_call_predictions
SET    predicted_value = 62            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'IND-W'
       );

-- kartik15 · W2 · BAN-W Powerplay  ← change 38 to new value
UPDATE closest_call_predictions
SET    predicted_value = 38            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'BAN-W'
       );

-- kartik15 · W2 · IND-W Sixes  ← change 9 to new value
UPDATE closest_call_predictions
SET    predicted_value = 9             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'IND-W'
       );

-- kartik15 · W2 · BAN-W Sixes  ← change 3 to new value
UPDATE closest_call_predictions
SET    predicted_value = 3             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'BAN-W'
       );


-- ============================================================
-- ══ kartik15 — MATCH W3: ENG-W vs NZ-W ══
-- Current values: ENG-W Final=145, NZ-W Final=158,
--                 ENG-W PP=52,    NZ-W PP=56,
--                 ENG-W Sixes=6,  NZ-W Sixes=8
-- ============================================================

-- kartik15 · W3 · ENG-W Final Score  ← change 145 to new value
UPDATE closest_call_predictions
SET    predicted_value = 145           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W3 · NZ-W Final Score  ← change 158 to new value
UPDATE closest_call_predictions
SET    predicted_value = 158           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'NZ-W'
       );

-- kartik15 · W3 · ENG-W Powerplay  ← change 52 to new value
UPDATE closest_call_predictions
SET    predicted_value = 52            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W3 · NZ-W Powerplay  ← change 56 to new value
UPDATE closest_call_predictions
SET    predicted_value = 56            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'NZ-W'
       );

-- kartik15 · W3 · ENG-W Sixes  ← change 6 to new value
UPDATE closest_call_predictions
SET    predicted_value = 6             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'ENG-W'
       );

-- kartik15 · W3 · NZ-W Sixes  ← change 8 to new value
UPDATE closest_call_predictions
SET    predicted_value = 8             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'kartik15')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'NZ-W'
       );


-- ============================================================
-- ══ knicksrulz_17 — MATCH W1: ENG-W vs WI-W ══
-- Current values: ENG-W Final=148, WI-W Final=138,
--                 ENG-W PP=52,    WI-W PP=46,
--                 ENG-W Sixes=6,  WI-W Sixes=7
-- ============================================================

-- knicksrulz_17 · W1 · ENG-W Final Score  ← change 148 to new value
UPDATE closest_call_predictions
SET    predicted_value = 148           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W1 · WI-W Final Score  ← change 138 to new value
UPDATE closest_call_predictions
SET    predicted_value = 138           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'WI-W'
       );

-- knicksrulz_17 · W1 · ENG-W Powerplay  ← change 52 to new value
UPDATE closest_call_predictions
SET    predicted_value = 52            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W1 · WI-W Powerplay  ← change 46 to new value
UPDATE closest_call_predictions
SET    predicted_value = 46            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'WI-W'
       );

-- knicksrulz_17 · W1 · ENG-W Sixes  ← change 6 to new value
UPDATE closest_call_predictions
SET    predicted_value = 6             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W1 · WI-W Sixes  ← change 7 to new value
UPDATE closest_call_predictions
SET    predicted_value = 7             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs WI-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'WI-W'
       );


-- ============================================================
-- ══ knicksrulz_17 — MATCH W2: IND-W vs BAN-W ══
-- Current values: IND-W Final=162, BAN-W Final=112,
--                 IND-W PP=60,    BAN-W PP=40,
--                 IND-W Sixes=8,  BAN-W Sixes=3
-- ============================================================

-- knicksrulz_17 · W2 · IND-W Final Score  ← change 162 to new value
UPDATE closest_call_predictions
SET    predicted_value = 162           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'IND-W'
       );

-- knicksrulz_17 · W2 · BAN-W Final Score  ← change 112 to new value
UPDATE closest_call_predictions
SET    predicted_value = 112           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'BAN-W'
       );

-- knicksrulz_17 · W2 · IND-W Powerplay  ← change 60 to new value
UPDATE closest_call_predictions
SET    predicted_value = 60            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'IND-W'
       );

-- knicksrulz_17 · W2 · BAN-W Powerplay  ← change 40 to new value
UPDATE closest_call_predictions
SET    predicted_value = 40            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'BAN-W'
       );

-- knicksrulz_17 · W2 · IND-W Sixes  ← change 8 to new value
UPDATE closest_call_predictions
SET    predicted_value = 8             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'IND-W'
       );

-- knicksrulz_17 · W2 · BAN-W Sixes  ← change 3 to new value
UPDATE closest_call_predictions
SET    predicted_value = 3             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'IND-W vs BAN-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'BAN-W'
       );


-- ============================================================
-- ══ knicksrulz_17 — MATCH W3: ENG-W vs NZ-W ══
-- Current values: ENG-W Final=140, NZ-W Final=162,
--                 ENG-W PP=50,    NZ-W PP=58,
--                 ENG-W Sixes=5,  NZ-W Sixes=9
-- ============================================================

-- knicksrulz_17 · W3 · ENG-W Final Score  ← change 140 to new value
UPDATE closest_call_predictions
SET    predicted_value = 140           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W3 · NZ-W Final Score  ← change 162 to new value
UPDATE closest_call_predictions
SET    predicted_value = 162           -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_final_score'
           AND  q.team_code     = 'NZ-W'
       );

-- knicksrulz_17 · W3 · ENG-W Powerplay  ← change 50 to new value
UPDATE closest_call_predictions
SET    predicted_value = 50            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W3 · NZ-W Powerplay  ← change 58 to new value
UPDATE closest_call_predictions
SET    predicted_value = 58            -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'team_score_6'
           AND  q.team_code     = 'NZ-W'
       );

-- knicksrulz_17 · W3 · ENG-W Sixes  ← change 5 to new value
UPDATE closest_call_predictions
SET    predicted_value = 5             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'ENG-W'
       );

-- knicksrulz_17 · W3 · NZ-W Sixes  ← change 9 to new value
UPDATE closest_call_predictions
SET    predicted_value = 9             -- ← REPLACE WITH NEW VALUE
WHERE  user_id    = (SELECT id FROM ipl_users WHERE user_name = 'knicksrulz_17')
  AND  question_id = (
         SELECT q.id FROM closest_call_questions q
         JOIN   closest_call_matches m ON m.id = q.closest_call_match_id
         WHERE  m.match_title   = 'ENG-W vs NZ-W — WT20 WC 2026'
           AND  q.question_type = 'total_sixes'
           AND  q.team_code     = 'NZ-W'
       );


-- ============================================================
-- STEP FINAL: POST-UPDATE VERIFICATION
-- Run this after your UPDATEs to confirm the new values saved.
-- ============================================================

SELECT
  u.user_name,
  m.match_title,
  q.question_type,
  q.team_code,
  q.innings_number,
  p.predicted_value,
  p.updated_at
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('kartik15', 'knicksrulz_17')
  AND  m.match_title IN (
         'ENG-W vs WI-W — WT20 WC 2026',
         'IND-W vs BAN-W — WT20 WC 2026',
         'ENG-W vs NZ-W — WT20 WC 2026'
       )
ORDER  BY u.user_name, m.match_date, q.innings_number, q.question_type;
