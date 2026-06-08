-- ============================================================
-- FILE: fix_player_roles.sql
-- PURPOSE: Add player_type to cricapi_player_master and
--          populate roles for all IPL / non-SL-WI players.
--
-- RUN ORDER:
--   Step 1 — Add the column (run once)
--   Step 2 — See which players need roles filled in
--   Step 3 — Bulk UPDATE with your assignments
--   Step 4 — Verify everything is filled
-- ============================================================


-- ============================================================
-- STEP 1: ADD player_type COLUMN
-- Run once. Safe to re-run — ALTER COLUMN IF NOT EXISTS.
-- ============================================================

ALTER TABLE cricapi_player_master
ADD COLUMN IF NOT EXISTS player_type TEXT;

-- Valid values (match cricket_player_pool exactly):
--   'Batsman'
--   'Bowler'
--   'All Rounder'
--   'Wicketkeeper'


-- ============================================================
-- STEP 2: SEE ALL PLAYERS WHO NEED A ROLE ASSIGNED
-- Run this first to get the full list before you start updating.
-- Copy the output into a spreadsheet, fill in player_type,
-- then build your UPDATE from Step 3.
-- ============================================================

SELECT
  ipm.player_name,
  ipm.country,
  ipm.player_type,           -- NULL until you fill it in
  pcsm.t20_bat_runs,
  pcsm.t20_bat_avg,
  pcsm.t20_bowl_wickets,
  pcsm.t20_bowl_economy
FROM cricapi_player_master ipm
LEFT JOIN player_career_stats_master pcsm
  ON LOWER(ipm.player_name) = LOWER(pcsm.player_name)
 AND LOWER(ipm.country)     = LOWER(pcsm.country)
WHERE ipm.player_type IS NULL
ORDER BY ipm.country, ipm.player_name;


-- ============================================================
-- STEP 3: BULK UPDATE — fill in roles for all IPL players
--
-- Replace the player names and roles below with your full list.
-- The CASE WHEN approach lets you do it all in one query.
--
-- IMPORTANT: player_name values must EXACTLY match what is
-- stored in cricapi_player_master (check with Step 2 output).
-- ============================================================

UPDATE cricapi_player_master
SET player_type = CASE player_name

  -- ── INDIA ──────────────────────────────────────────────
  WHEN 'Jasprit Bumrah'          THEN 'Bowler'
  WHEN 'Arshdeep Singh'          THEN 'Bowler'
  WHEN 'Axar Patel'              THEN 'All Rounder'
  WHEN 'Kuldeep Yadav'           THEN 'Bowler'
  WHEN 'Ravindra Jadeja'         THEN 'All Rounder'
  WHEN 'Washington Sundar'       THEN 'All Rounder'
  WHEN 'Ravi Bishnoi'            THEN 'Bowler'
  WHEN 'Varun Chakaravarthy'     THEN 'Bowler'
  WHEN 'Mohammed Siraj'          THEN 'Bowler'
  WHEN 'Prasidh Krishna'         THEN 'Bowler'
  WHEN 'Harshit Rana'            THEN 'Bowler'
  WHEN 'Akash Deep'              THEN 'Bowler'
  WHEN 'Mukesh Kumar'            THEN 'Bowler'
  WHEN 'Prince Yadav'            THEN 'Bowler'
  WHEN 'Shivam Dube'             THEN 'All Rounder'
  WHEN 'Nitish Kumar Reddy'      THEN 'All Rounder'
  WHEN 'Virat Kohli'             THEN 'Batsman'
  WHEN 'Rohit Sharma'            THEN 'Batsman'
  WHEN 'KL Rahul'                THEN 'Batsman'
  WHEN 'Shreyas Iyer'            THEN 'Batsman'
  WHEN 'Yashasvi Jaiswal'        THEN 'Batsman'
  WHEN 'Shubman Gill'            THEN 'Batsman'
  WHEN 'Tilak Varma'             THEN 'Batsman'
  WHEN 'Abhishek Sharma'         THEN 'Batsman'
  WHEN 'Sanju Samson'            THEN 'Batsman'
  WHEN 'Ishan Kishan'            THEN 'Batsman'
  WHEN 'Devdutt Padikkal'        THEN 'Batsman'
  WHEN 'Sarfaraz Khan'           THEN 'Batsman'
  WHEN 'Sai Sudharsan'           THEN 'Batsman'
  WHEN 'Vaibhav Sooryavanshi'    THEN 'Batsman'
  WHEN 'Rishabh Pant'            THEN 'Wicketkeeper'
  WHEN 'Dhruv Jurel'             THEN 'Wicketkeeper'

  -- ── AUSTRALIA ──────────────────────────────────────────
  WHEN 'Adam Zampa'              THEN 'Bowler'
  WHEN 'Josh Hazlewood'          THEN 'Bowler'
  WHEN 'Pat Cummins'             THEN 'Bowler'
  WHEN 'Mitchell Starc'          THEN 'Bowler'
  WHEN 'Nathan Lyon'             THEN 'Bowler'
  WHEN 'Glenn Maxwell'           THEN 'Batsman'
  WHEN 'Mitchell Marsh'          THEN 'Batsman'
  WHEN 'Marnus Labuschagne'      THEN 'Batsman'
  WHEN 'Usman Khawaja'           THEN 'Batsman'
  WHEN 'Alex Carey'              THEN 'Wicketkeeper'

  -- ── ENGLAND ────────────────────────────────────────────
  WHEN 'Ben Stokes'              THEN 'All Rounder'
  WHEN 'Rehan Ahmed'             THEN 'Bowler'
  WHEN 'Gus Atkinson'            THEN 'Bowler'
  WHEN 'Matthew Fisher'          THEN 'Bowler'
  WHEN 'James Rew'               THEN 'Bowler'
  WHEN 'Josh Tongue'             THEN 'Bowler'
  WHEN 'Ollie Robinson'          THEN 'Bowler'
  WHEN 'Shoaib Bashir'           THEN 'Bowler'
  WHEN 'Sonny Baker'             THEN 'Bowler'
  WHEN 'Joe Root'                THEN 'Batsman'
  WHEN 'Harry Brook'             THEN 'Batsman'
  WHEN 'Ben Duckett'             THEN 'Batsman'
  WHEN 'Jacob Bethell'           THEN 'Batsman'
  WHEN 'Emilio Gay'              THEN 'Batsman'
  WHEN 'Jamie Smith'             THEN 'Wicketkeeper'

  -- ── NEW ZEALAND ────────────────────────────────────────
  WHEN 'Matt Henry'              THEN 'Bowler'
  WHEN 'Blair Tickner'           THEN 'Bowler'
  WHEN 'Kyle Jamieson'           THEN 'Bowler'
  WHEN 'Zakary Foulkes'          THEN 'Bowler'
  WHEN 'William ORourke'         THEN 'Bowler'
  WHEN 'Rachin Ravindra'         THEN 'All Rounder'
  WHEN 'Kane Williamson'         THEN 'Batsman'
  WHEN 'Daryl Mitchell'          THEN 'Batsman'
  WHEN 'Glenn Phillips'          THEN 'Batsman'
  WHEN 'Devon Conway'            THEN 'Batsman'
  WHEN 'Tom Latham'              THEN 'Batsman'
  WHEN 'Henry Nicholls'          THEN 'Batsman'
  WHEN 'Tom Blundell'            THEN 'Batsman'
  WHEN 'Dean Foxcroft'           THEN 'Batsman'
  WHEN 'Nathan Smith'            THEN 'Wicketkeeper'

  -- ── PAKISTAN ───────────────────────────────────────────
  WHEN 'Haris Rauf'              THEN 'Bowler'
  WHEN 'Shadab Khan'             THEN 'All Rounder'
  WHEN 'Naseem Shah'             THEN 'Bowler'
  WHEN 'Saim Ayub'               THEN 'All Rounder'
  WHEN 'Babar Azam'              THEN 'Batsman'
  WHEN 'Fakhar Zaman'            THEN 'Batsman'
  WHEN 'Imam-ul-Haq'             THEN 'Batsman'
  WHEN 'Abdullah Shafique'       THEN 'Batsman'
  WHEN 'Mohammad Rizwan'         THEN 'Wicketkeeper'

  -- ── AFGHANISTAN ────────────────────────────────────────
  WHEN 'Mohammad Nabi'           THEN 'All Rounder'
  WHEN 'Naveen-ul-Haq'           THEN 'Bowler'
  WHEN 'Mujeeb Ur Rahman'        THEN 'Bowler'
  WHEN 'Fazalhaq Farooqi'        THEN 'Bowler'
  WHEN 'Qais Ahmad'              THEN 'Bowler'
  WHEN 'Noor Ahmad'              THEN 'Bowler'
  WHEN 'Rashid Khan'             THEN 'All Rounder'
  WHEN 'Azmatullah Omarzai'      THEN 'All Rounder'
  WHEN 'Gulbadin Naib'           THEN 'Batsman'
  WHEN 'Abdul Malik'             THEN 'Batsman'
  WHEN 'Ibrahim Zadran'          THEN 'Batsman'
  WHEN 'Rahmanullah Gurbaz'      THEN 'Batsman'
  WHEN 'Hashmatullah Shahidi'    THEN 'Batsman'
  WHEN 'Afsar Zazai'             THEN 'Batsman'

  -- ── SRI LANKA (cricapi_player_master only) ─────────────
  WHEN 'Wanindu Hasaranga'       THEN 'All Rounder'
  WHEN 'Maheesh Theekshana'      THEN 'Bowler'
  WHEN 'Dushmantha Chameera'     THEN 'Bowler'
  WHEN 'Dilshan Madushanka'      THEN 'Bowler'
  WHEN 'Pramod Madushan'         THEN 'Bowler'
  WHEN 'Dunith Wellalage'        THEN 'Bowler'
  WHEN 'Asitha Fernando'         THEN 'Bowler'
  WHEN 'Eshan Malinga'           THEN 'Bowler'
  WHEN 'Pavan Rathnayake'        THEN 'Bowler'
  WHEN 'Charith Asalanka'        THEN 'Batsman'
  WHEN 'Kamindu Mendis'          THEN 'Batsman'
  WHEN 'Kusal Mendis'            THEN 'Batsman'
  WHEN 'Pathum Nissanka'         THEN 'Batsman'
  WHEN 'Janith Liyanage'         THEN 'Batsman'
  WHEN 'Kamil Mishara'           THEN 'Batsman'

  -- ── WEST INDIES (cricapi_player_master only) ───────────
  WHEN 'Alzarri Joseph'          THEN 'Bowler'
  WHEN 'Gudakesh Motie'          THEN 'All Rounder'
  WHEN 'Roston Chase'            THEN 'All Rounder'
  WHEN 'Shamar Springer'         THEN 'Bowler'
  WHEN 'Shamar Joseph'           THEN 'Bowler'
  WHEN 'Matthew Forde'           THEN 'Bowler'
  WHEN 'Jayden Seales'           THEN 'Bowler'
  WHEN 'Sherfane Rutherford'     THEN 'Batsman'
  WHEN 'Shimron Hetmyer'         THEN 'Batsman'
  WHEN 'Shai Hope'               THEN 'Batsman'
  WHEN 'Amir Jangoo'             THEN 'Batsman'
  WHEN 'Ackeem Auguste'          THEN 'Batsman'
  WHEN 'Keacy Carty'             THEN 'Batsman'
  WHEN 'John Campbell'           THEN 'Batsman'
  WHEN 'Justin Greaves'          THEN 'Wicketkeeper'

  ELSE player_type   -- leave existing values untouched
END
WHERE player_type IS NULL
   OR player_type NOT IN ('Batsman', 'Bowler', 'All Rounder', 'Wicketkeeper');


-- ============================================================
-- STEP 4: VERIFY — check how many players still have no role
-- Target: 0 rows (all players classified).
-- If you see rows here, add them to the CASE WHEN above
-- and re-run the UPDATE.
-- ============================================================

SELECT
  ipm.player_name,
  ipm.country,
  ipm.player_type
FROM cricapi_player_master ipm
WHERE ipm.player_type IS NULL
ORDER BY ipm.country, ipm.player_name;

-- Quick summary count by role
SELECT player_type, COUNT(*) AS players
FROM cricapi_player_master
GROUP BY player_type
ORDER BY player_type NULLS FIRST;
