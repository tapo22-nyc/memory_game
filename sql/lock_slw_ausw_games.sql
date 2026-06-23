-- ============================================================
-- FILE: sql/lock_slw_ausw_games.sql
-- PURPOSE: Lock SL-W vs IRE-W and AUS-W vs PAK-W matches
--          so no more predictions can be submitted.
--          After running this, score both games via manual-scoring.html.
--
-- RUN ON: Neon DB console
-- ============================================================

-- ── Lock both matches ─────────────────────────────────────────
UPDATE closest_call_matches
SET    status     = 'locked',
       updated_at = NOW()
WHERE  match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026'
);

-- ── Lock all questions for both matches ───────────────────────
UPDATE closest_call_questions
SET    status     = 'locked',
       updated_at = NOW()
WHERE  closest_call_match_id IN (
  SELECT id FROM closest_call_matches
  WHERE  match_title IN (
    'SL-W vs IRE-W — WT20 WC 2026',
    'AUS-W vs PAK-W — WT20 WC 2026'
  )
)
AND status = 'open';

-- ── Verify ────────────────────────────────────────────────────
SELECT m.id, m.match_title, m.status AS match_status,
       COUNT(q.id) AS total_questions,
       COUNT(CASE WHEN q.status = 'locked' THEN 1 END) AS locked_questions
FROM   closest_call_matches m
LEFT JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE  m.match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026'
)
GROUP BY m.id, m.match_title, m.status
ORDER BY m.id;
