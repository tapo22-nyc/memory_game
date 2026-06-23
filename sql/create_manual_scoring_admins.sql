-- ============================================================
-- FILE: sql/create_manual_scoring_admins.sql
-- PURPOSE: Create the admin table for Closest Call manual scoring
--          and insert the authorized admin user.
--
-- RUN ONCE on the Neon PostgreSQL database.
--
-- INSTRUCTIONS:
--   1. Replace REPLACE_WITH_EMAIL with the admin email address.
--   2. Replace REPLACE_WITH_MASTER_PASSWORD with any password you choose.
--   3. Replace REPLACE_WITH_6_DIGIT_CODE with any 6-digit number you choose.
--   4. Run this file on your Neon DB.
--
-- No hashing or environment variables needed.
-- ============================================================

CREATE TABLE IF NOT EXISTS closest_call_manual_admins (
  id               SERIAL PRIMARY KEY,
  username         TEXT NOT NULL UNIQUE,
  email            TEXT NOT NULL,
  scoring_password TEXT NOT NULL,
  scoring_code     TEXT NOT NULL,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  session_token    TEXT,
  session_expires_at TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Insert authorized admin ────────────────────────────────────
-- Replace the three placeholder values below, then run this file.
INSERT INTO closest_call_manual_admins
  (username, email, scoring_password, scoring_code, is_active)
VALUES (
  'ami_kolkata',
  'REPLACE_WITH_EMAIL',
  'REPLACE_WITH_MASTER_PASSWORD',
  'REPLACE_WITH_6_DIGIT_CODE',
  TRUE
)
ON CONFLICT (username) DO UPDATE
  SET email            = EXCLUDED.email,
      scoring_password = EXCLUDED.scoring_password,
      scoring_code     = EXCLUDED.scoring_code,
      is_active        = EXCLUDED.is_active,
      updated_at       = NOW();

-- ── Verify the record ─────────────────────────────────────────
SELECT id, username, email, scoring_password, scoring_code, is_active, created_at
FROM   closest_call_manual_admins;
