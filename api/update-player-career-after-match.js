import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

// ─────────────────────────────────────────────────────────────
// update-player-career-after-match.js
//
// PURPOSE:
//   After a fantasy match ends (status → 'closed'), this API
//   re-fetches career stats from CricAPI for every player who
//   played in that match and updates player_career_stats_master.
//
//   This keeps the career totals table current automatically
//   after every real-world match — no manual sync needed.
//
// HOW TO TRIGGER:
//   Call this manually after scoring, OR add a call to it
//   inside recalculate-fantasy-user-scores.js once scoring
//   is complete:
//
//     await fetch(`${process.env.BASE_URL}/api/update-player-career-after-match?fantasy_match_id=5`);
//
// USAGE:
//   GET /api/update-player-career-after-match?fantasy_match_id=5
//
// AUTHORIZATION:
//   Checks for Bearer CRON_SECRET header so it can't be
//   triggered by random users. Same pattern as lock-fantasy-match.
// ─────────────────────────────────────────────────────────────

async function fetchPlayerInfo(playerId) {
  const url =
    `https://api.cricapi.com/v1/players_info?apikey=${process.env.CRICAPI_KEY}` +
    `&id=${encodeURIComponent(playerId)}`;
  const response = await fetch(url);
  const data = await response.json();
  if (!response.ok || data.status === "failure") {
    throw new Error(`CricAPI failed for ${playerId}: ${data.reason || response.status}`);
  }
  return data;
}

function norm(v) { return String(v || "").trim().toLowerCase(); }

function statNum(statsArray, format, type, statName) {
  for (const row of statsArray || []) {
    if (
      norm(row.fn) === type && norm(row.stat) === statName &&
      (norm(row.matchtype) === format || norm(row.matchtype) === format + "i")
    ) {
      const v = parseFloat(String(row.value || "").replace(/[^0-9.]/g, ""));
      return isNaN(v) ? null : v;
    }
  }
  return null;
}

function statText(statsArray, format, type, statName) {
  for (const row of statsArray || []) {
    if (
      norm(row.fn) === type && norm(row.stat) === statName &&
      (norm(row.matchtype) === format || norm(row.matchtype) === format + "i")
    ) {
      return String(row.value || "").trim() || null;
    }
  }
  return null;
}

function buildFlatStats(s) {
  return {
    odi_bat_matches: statNum(s,"odi","batting","m"), odi_bat_innings: statNum(s,"odi","batting","inn"),
    odi_bat_not_outs: statNum(s,"odi","batting","no"), odi_bat_runs: statNum(s,"odi","batting","runs"),
    odi_bat_highest: statText(s,"odi","batting","hs"), odi_bat_avg: statNum(s,"odi","batting","avg"),
    odi_bat_balls_faced: statNum(s,"odi","batting","bf"), odi_bat_strike_rate: statNum(s,"odi","batting","sr"),
    odi_bat_100s: statNum(s,"odi","batting","100s"), odi_bat_50s: statNum(s,"odi","batting","50s"),
    odi_bat_4s: statNum(s,"odi","batting","4s"), odi_bat_6s: statNum(s,"odi","batting","6s"),
    odi_bowl_matches: statNum(s,"odi","bowling","m"), odi_bowl_innings: statNum(s,"odi","bowling","inn"),
    odi_bowl_balls: statNum(s,"odi","bowling","balls"), odi_bowl_runs: statNum(s,"odi","bowling","runs"),
    odi_bowl_wickets: statNum(s,"odi","bowling","wkts"), odi_bowl_avg: statNum(s,"odi","bowling","avg"),
    odi_bowl_economy: statNum(s,"odi","bowling","econ"), odi_bowl_strike_rate: statNum(s,"odi","bowling","sr"),
    odi_bowl_5wi: statNum(s,"odi","bowling","5w"),
    t20_bat_matches: statNum(s,"t20","batting","m"), t20_bat_innings: statNum(s,"t20","batting","inn"),
    t20_bat_not_outs: statNum(s,"t20","batting","no"), t20_bat_runs: statNum(s,"t20","batting","runs"),
    t20_bat_highest: statText(s,"t20","batting","hs"), t20_bat_avg: statNum(s,"t20","batting","avg"),
    t20_bat_balls_faced: statNum(s,"t20","batting","bf"), t20_bat_strike_rate: statNum(s,"t20","batting","sr"),
    t20_bat_100s: statNum(s,"t20","batting","100s"), t20_bat_50s: statNum(s,"t20","batting","50s"),
    t20_bat_4s: statNum(s,"t20","batting","4s"), t20_bat_6s: statNum(s,"t20","batting","6s"),
    t20_bowl_matches: statNum(s,"t20","bowling","m"), t20_bowl_innings: statNum(s,"t20","bowling","inn"),
    t20_bowl_balls: statNum(s,"t20","bowling","balls"), t20_bowl_runs: statNum(s,"t20","bowling","runs"),
    t20_bowl_wickets: statNum(s,"t20","bowling","wkts"), t20_bowl_avg: statNum(s,"t20","bowling","avg"),
    t20_bowl_economy: statNum(s,"t20","bowling","econ"), t20_bowl_strike_rate: statNum(s,"t20","bowling","sr"),
    t20_bowl_5wi: statNum(s,"t20","bowling","5w"),
    test_bat_matches: statNum(s,"test","batting","m"), test_bat_innings: statNum(s,"test","batting","inn"),
    test_bat_not_outs: statNum(s,"test","batting","no"), test_bat_runs: statNum(s,"test","batting","runs"),
    test_bat_highest: statText(s,"test","batting","hs"), test_bat_avg: statNum(s,"test","batting","avg"),
    test_bat_balls_faced: statNum(s,"test","batting","bf"), test_bat_strike_rate: statNum(s,"test","batting","sr"),
    test_bat_100s: statNum(s,"test","batting","100s"), test_bat_50s: statNum(s,"test","batting","50s"),
    test_bat_4s: statNum(s,"test","batting","4s"), test_bat_6s: statNum(s,"test","batting","6s"),
    test_bowl_matches: statNum(s,"test","bowling","m"), test_bowl_innings: statNum(s,"test","bowling","inn"),
    test_bowl_balls: statNum(s,"test","bowling","balls"), test_bowl_runs: statNum(s,"test","bowling","runs"),
    test_bowl_wickets: statNum(s,"test","bowling","wkts"), test_bowl_avg: statNum(s,"test","bowling","avg"),
    test_bowl_economy: statNum(s,"test","bowling","econ"), test_bowl_strike_rate: statNum(s,"test","bowling","sr"),
    test_bowl_5wi: statNum(s,"test","bowling","5w"), test_bowl_10wi: statNum(s,"test","bowling","10w"),
  };
}

export default async function handler(req, res) {
  try {
    // ── Auth check — same pattern as lock-fantasy-match ────────
    const authHeader = req.headers.authorization;
    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const fantasyMatchId = Number(req.query.fantasy_match_id);
    if (!fantasyMatchId) {
      return res.status(400).json({ error: "Missing ?fantasy_match_id=<id>" });
    }

    // ── Find all players in this match with their CricAPI IDs ──
    // Covers both IPL players (ipl_player_master) and pool players
    // (cricket_player_pool) by checking their respective tables.
    const players = await sql`
      SELECT
        fmp.player_id,
        fmp.player_source,
        COALESCE(ipm.player_name, cpp.player_name)  AS player_name,
        COALESCE(ipm.team_code,   cpp.country)       AS country,
        -- IPL players: CricAPI ID direct from master table
        -- Pool players: CricAPI ID via cricsheet_player_mapping
        COALESCE(
          ipm.cricapi_player_id,
          cpm.cricapi_player_id
        )                                            AS cricapi_player_id,
        CASE
          WHEN fmp.player_source = 'ipl' THEN 'ipl'
          ELSE 'cricket'
        END                                          AS pool_source
      FROM fantasy_match_players fmp
      LEFT JOIN ipl_player_master ipm
             ON ipm.id = fmp.player_id
            AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
      LEFT JOIN cricket_player_pool cpp
             ON cpp.id = fmp.player_id
            AND fmp.player_source = 'cricket'
      LEFT JOIN cricsheet_player_mapping cpm
             ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
            AND cpm.country = cpp.country
            AND cpm.mapping_status = 'mapped'
      WHERE fmp.fantasy_match_id = ${fantasyMatchId}
    `;

    if (players.length === 0) {
      return res.status(404).json({
        success: false,
        error: `No players found for fantasy_match_id=${fantasyMatchId}`
      });
    }

    // Filter to only players who have a CricAPI ID
    const playersWithId    = players.filter(p => p.cricapi_player_id);
    const playersWithoutId = players.filter(p => !p.cricapi_player_id);

    const results = [];

    for (const player of playersWithId) {
      try {
        const apiData    = await fetchPlayerInfo(player.cricapi_player_id);
        const playerData = apiData.data || apiData;
        const stats      = playerData.stats || [];
        const flat       = buildFlatStats(stats);

        await sql`
          INSERT INTO player_career_stats_master (
            player_name, country, cricapi_player_id, player_pool_source,
            odi_bat_matches, odi_bat_innings, odi_bat_not_outs, odi_bat_runs,
            odi_bat_highest, odi_bat_avg, odi_bat_balls_faced, odi_bat_strike_rate,
            odi_bat_100s, odi_bat_50s, odi_bat_4s, odi_bat_6s,
            odi_bowl_matches, odi_bowl_innings, odi_bowl_balls, odi_bowl_runs,
            odi_bowl_wickets, odi_bowl_avg, odi_bowl_economy, odi_bowl_strike_rate, odi_bowl_5wi,
            t20_bat_matches, t20_bat_innings, t20_bat_not_outs, t20_bat_runs,
            t20_bat_highest, t20_bat_avg, t20_bat_balls_faced, t20_bat_strike_rate,
            t20_bat_100s, t20_bat_50s, t20_bat_4s, t20_bat_6s,
            t20_bowl_matches, t20_bowl_innings, t20_bowl_balls, t20_bowl_runs,
            t20_bowl_wickets, t20_bowl_avg, t20_bowl_economy, t20_bowl_strike_rate, t20_bowl_5wi,
            test_bat_matches, test_bat_innings, test_bat_not_outs, test_bat_runs,
            test_bat_highest, test_bat_avg, test_bat_balls_faced, test_bat_strike_rate,
            test_bat_100s, test_bat_50s, test_bat_4s, test_bat_6s,
            test_bowl_matches, test_bowl_innings, test_bowl_balls, test_bowl_runs,
            test_bowl_wickets, test_bowl_avg, test_bowl_economy, test_bowl_strike_rate,
            test_bowl_5wi, test_bowl_10wi,
            data_source, last_synced_at, updated_at
          )
          VALUES (
            ${playerData.name || player.player_name},
            ${playerData.country || player.country},
            ${player.cricapi_player_id},
            ${player.pool_source},
            ${flat.odi_bat_matches}, ${flat.odi_bat_innings}, ${flat.odi_bat_not_outs}, ${flat.odi_bat_runs},
            ${flat.odi_bat_highest}, ${flat.odi_bat_avg}, ${flat.odi_bat_balls_faced}, ${flat.odi_bat_strike_rate},
            ${flat.odi_bat_100s}, ${flat.odi_bat_50s}, ${flat.odi_bat_4s}, ${flat.odi_bat_6s},
            ${flat.odi_bowl_matches}, ${flat.odi_bowl_innings}, ${flat.odi_bowl_balls}, ${flat.odi_bowl_runs},
            ${flat.odi_bowl_wickets}, ${flat.odi_bowl_avg}, ${flat.odi_bowl_economy}, ${flat.odi_bowl_strike_rate}, ${flat.odi_bowl_5wi},
            ${flat.t20_bat_matches}, ${flat.t20_bat_innings}, ${flat.t20_bat_not_outs}, ${flat.t20_bat_runs},
            ${flat.t20_bat_highest}, ${flat.t20_bat_avg}, ${flat.t20_bat_balls_faced}, ${flat.t20_bat_strike_rate},
            ${flat.t20_bat_100s}, ${flat.t20_bat_50s}, ${flat.t20_bat_4s}, ${flat.t20_bat_6s},
            ${flat.t20_bowl_matches}, ${flat.t20_bowl_innings}, ${flat.t20_bowl_balls}, ${flat.t20_bowl_runs},
            ${flat.t20_bowl_wickets}, ${flat.t20_bowl_avg}, ${flat.t20_bowl_economy}, ${flat.t20_bowl_strike_rate}, ${flat.t20_bowl_5wi},
            ${flat.test_bat_matches}, ${flat.test_bat_innings}, ${flat.test_bat_not_outs}, ${flat.test_bat_runs},
            ${flat.test_bat_highest}, ${flat.test_bat_avg}, ${flat.test_bat_balls_faced}, ${flat.test_bat_strike_rate},
            ${flat.test_bat_100s}, ${flat.test_bat_50s}, ${flat.test_bat_4s}, ${flat.test_bat_6s},
            ${flat.test_bowl_matches}, ${flat.test_bowl_innings}, ${flat.test_bowl_balls}, ${flat.test_bowl_runs},
            ${flat.test_bowl_wickets}, ${flat.test_bowl_avg}, ${flat.test_bowl_economy}, ${flat.test_bowl_strike_rate},
            ${flat.test_bowl_5wi}, ${flat.test_bowl_10wi},
            'cricapi', NOW(), NOW()
          )
          ON CONFLICT (player_name, country) DO UPDATE SET
            cricapi_player_id = EXCLUDED.cricapi_player_id,
            odi_bat_matches = EXCLUDED.odi_bat_matches, odi_bat_innings = EXCLUDED.odi_bat_innings,
            odi_bat_not_outs = EXCLUDED.odi_bat_not_outs, odi_bat_runs = EXCLUDED.odi_bat_runs,
            odi_bat_highest = EXCLUDED.odi_bat_highest, odi_bat_avg = EXCLUDED.odi_bat_avg,
            odi_bat_balls_faced = EXCLUDED.odi_bat_balls_faced, odi_bat_strike_rate = EXCLUDED.odi_bat_strike_rate,
            odi_bat_100s = EXCLUDED.odi_bat_100s, odi_bat_50s = EXCLUDED.odi_bat_50s,
            odi_bat_4s = EXCLUDED.odi_bat_4s, odi_bat_6s = EXCLUDED.odi_bat_6s,
            odi_bowl_matches = EXCLUDED.odi_bowl_matches, odi_bowl_innings = EXCLUDED.odi_bowl_innings,
            odi_bowl_balls = EXCLUDED.odi_bowl_balls, odi_bowl_runs = EXCLUDED.odi_bowl_runs,
            odi_bowl_wickets = EXCLUDED.odi_bowl_wickets, odi_bowl_avg = EXCLUDED.odi_bowl_avg,
            odi_bowl_economy = EXCLUDED.odi_bowl_economy, odi_bowl_strike_rate = EXCLUDED.odi_bowl_strike_rate,
            odi_bowl_5wi = EXCLUDED.odi_bowl_5wi,
            t20_bat_matches = EXCLUDED.t20_bat_matches, t20_bat_innings = EXCLUDED.t20_bat_innings,
            t20_bat_not_outs = EXCLUDED.t20_bat_not_outs, t20_bat_runs = EXCLUDED.t20_bat_runs,
            t20_bat_highest = EXCLUDED.t20_bat_highest, t20_bat_avg = EXCLUDED.t20_bat_avg,
            t20_bat_balls_faced = EXCLUDED.t20_bat_balls_faced, t20_bat_strike_rate = EXCLUDED.t20_bat_strike_rate,
            t20_bat_100s = EXCLUDED.t20_bat_100s, t20_bat_50s = EXCLUDED.t20_bat_50s,
            t20_bat_4s = EXCLUDED.t20_bat_4s, t20_bat_6s = EXCLUDED.t20_bat_6s,
            t20_bowl_matches = EXCLUDED.t20_bowl_matches, t20_bowl_innings = EXCLUDED.t20_bowl_innings,
            t20_bowl_balls = EXCLUDED.t20_bowl_balls, t20_bowl_runs = EXCLUDED.t20_bowl_runs,
            t20_bowl_wickets = EXCLUDED.t20_bowl_wickets, t20_bowl_avg = EXCLUDED.t20_bowl_avg,
            t20_bowl_economy = EXCLUDED.t20_bowl_economy, t20_bowl_strike_rate = EXCLUDED.t20_bowl_strike_rate,
            t20_bowl_5wi = EXCLUDED.t20_bowl_5wi,
            test_bat_matches = EXCLUDED.test_bat_matches, test_bat_innings = EXCLUDED.test_bat_innings,
            test_bat_not_outs = EXCLUDED.test_bat_not_outs, test_bat_runs = EXCLUDED.test_bat_runs,
            test_bat_highest = EXCLUDED.test_bat_highest, test_bat_avg = EXCLUDED.test_bat_avg,
            test_bat_balls_faced = EXCLUDED.test_bat_balls_faced, test_bat_strike_rate = EXCLUDED.test_bat_strike_rate,
            test_bat_100s = EXCLUDED.test_bat_100s, test_bat_50s = EXCLUDED.test_bat_50s,
            test_bat_4s = EXCLUDED.test_bat_4s, test_bat_6s = EXCLUDED.test_bat_6s,
            test_bowl_matches = EXCLUDED.test_bowl_matches, test_bowl_innings = EXCLUDED.test_bowl_innings,
            test_bowl_balls = EXCLUDED.test_bowl_balls, test_bowl_runs = EXCLUDED.test_bowl_runs,
            test_bowl_wickets = EXCLUDED.test_bowl_wickets, test_bowl_avg = EXCLUDED.test_bowl_avg,
            test_bowl_economy = EXCLUDED.test_bowl_economy, test_bowl_strike_rate = EXCLUDED.test_bowl_strike_rate,
            test_bowl_5wi = EXCLUDED.test_bowl_5wi, test_bowl_10wi = EXCLUDED.test_bowl_10wi,
            last_synced_at = NOW(), updated_at = NOW()
        `;

        results.push({ player_name: player.player_name, country: player.country, status: "updated" });

      } catch (playerErr) {
        results.push({ player_name: player.player_name, country: player.country, status: "error", error: playerErr.message });
      }
    }

    // Report players skipped due to missing CricAPI ID
    for (const p of playersWithoutId) {
      results.push({
        player_name: p.player_name,
        country: p.country,
        status: "skipped",
        reason: "No cricapi_player_id — run sync-pool-player-cricapi-ids first"
      });
    }

    return res.status(200).json({
      success: true,
      fantasy_match_id: fantasyMatchId,
      total_players_in_match: players.length,
      updated: results.filter(r => r.status === "updated").length,
      skipped: results.filter(r => r.status === "skipped").length,
      errors:  results.filter(r => r.status === "error").length,
      results
    });

  } catch (error) {
    console.error("update-player-career-after-match error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }
}
