import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

// ─────────────────────────────────────────────────────────────
// sync-selected-player-career-stats.js  (updated)
//
// WHAT CHANGED:
//   Previously only processed IPL players from cricapi_player_master.
//   Now also processes SL/WI/international players from
//   cricket_player_pool joined to cricsheet_player_mapping
//   (which holds their cricapi_player_id after running
//    sync-pool-player-cricapi-ids).
//
//   Writes to TWO tables:
//     1. cricapi_player_career_stats  — existing JSON blob table
//                                       (backwards compatible, unchanged)
//     2. player_career_stats_master   — NEW flat-column table
//                                       (queryable without JSON parsing)
//
// USAGE:
//   GET /api/sync-selected-player-career-stats
//       ?source=all          all players (default)
//       ?source=ipl          IPL players only
//       ?source=pool         cricket_player_pool players only
//       ?player=Kusal Mendis single player by name
// ─────────────────────────────────────────────────────────────

async function fetchPlayerInfo(playerId) {
  const url =
    `https://api.cricapi.com/v1/players_info?apikey=${process.env.CRICAPI_KEY}` +
    `&id=${encodeURIComponent(playerId)}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`CricAPI players_info failed for ${playerId}: ${data.reason || JSON.stringify(data)}`);
  }

  return data;
}

function norm(value) {
  return String(value || "").trim().toLowerCase();
}

// ── Extract a JSON blob for the old cricapi_player_career_stats table ──
function buildStatsObject(statsArray, format, type) {
  if (!Array.isArray(statsArray)) return null;
  const output = {};
  for (const row of statsArray) {
    if (norm(row.fn) === type && norm(row.matchtype) === format) {
      output[norm(row.stat)] = String(row.value || "").trim();
    }
  }
  return Object.keys(output).length > 0 ? output : null;
}

// ── Extract a single stat value as a number (or null) ──
function statNum(statsArray, format, type, statName) {
  if (!Array.isArray(statsArray)) return null;
  for (const row of statsArray) {
    if (
      norm(row.fn) === type &&
      norm(row.stat) === statName &&
      (norm(row.matchtype) === format || norm(row.matchtype) === format + "i")
    ) {
      const v = parseFloat(String(row.value || "").replace(/[^0-9.]/g, ""));
      return isNaN(v) ? null : v;
    }
  }
  return null;
}

// ── Extract highest score — kept as TEXT because of the '*' not-out marker ──
function statText(statsArray, format, type, statName) {
  if (!Array.isArray(statsArray)) return null;
  for (const row of statsArray) {
    if (
      norm(row.fn) === type &&
      norm(row.stat) === statName &&
      (norm(row.matchtype) === format || norm(row.matchtype) === format + "i")
    ) {
      return String(row.value || "").trim() || null;
    }
  }
  return null;
}

// ── Build the flat object for player_career_stats_master ──
function buildFlatStats(statsArray) {
  const s = statsArray || [];
  return {
    // ODI batting
    odi_bat_matches:      statNum(s, "odi", "batting", "mat"),
    odi_bat_innings:      statNum(s, "odi", "batting", "inns"),
    odi_bat_not_outs:     statNum(s, "odi", "batting", "no"),
    odi_bat_runs:         statNum(s, "odi", "batting", "runs"),
    odi_bat_highest:      statText(s, "odi", "batting", "hs"),
    odi_bat_avg:          statNum(s, "odi", "batting", "avg"),
    odi_bat_balls_faced:  statNum(s, "odi", "batting", "bf"),
    odi_bat_strike_rate:  statNum(s, "odi", "batting", "sr"),
    odi_bat_100s:         statNum(s, "odi", "batting", "100"),
    odi_bat_50s:          statNum(s, "odi", "batting", "50"),
    odi_bat_4s:           statNum(s, "odi", "batting", "4s"),
    odi_bat_6s:           statNum(s, "odi", "batting", "6s"),
    // ODI bowling
    odi_bowl_matches:     statNum(s, "odi", "bowling", "mat"),
    odi_bowl_innings:     statNum(s, "odi", "bowling", "inns"),
    odi_bowl_balls:       statNum(s, "odi", "bowling", "balls"),
    odi_bowl_runs:        statNum(s, "odi", "bowling", "runs"),
    odi_bowl_wickets:     statNum(s, "odi", "bowling", "wkts"),
    odi_bowl_avg:         statNum(s, "odi", "bowling", "avg"),
    odi_bowl_economy:     statNum(s, "odi", "bowling", "econ"),
    odi_bowl_strike_rate: statNum(s, "odi", "bowling", "sr"),
    odi_bowl_5wi:         statNum(s, "odi", "bowling", "5w"),
    // T20 batting
    t20_bat_matches:      statNum(s, "t20", "batting", "mat"),
    t20_bat_innings:      statNum(s, "t20", "batting", "inns"),
    t20_bat_not_outs:     statNum(s, "t20", "batting", "no"),
    t20_bat_runs:         statNum(s, "t20", "batting", "runs"),
    t20_bat_highest:      statText(s, "t20", "batting", "hs"),
    t20_bat_avg:          statNum(s, "t20", "batting", "avg"),
    t20_bat_balls_faced:  statNum(s, "t20", "batting", "bf"),
    t20_bat_strike_rate:  statNum(s, "t20", "batting", "sr"),
    t20_bat_100s:         statNum(s, "t20", "batting", "100"),
    t20_bat_50s:          statNum(s, "t20", "batting", "50"),
    t20_bat_4s:           statNum(s, "t20", "batting", "4s"),
    t20_bat_6s:           statNum(s, "t20", "batting", "6s"),
    // T20 bowling
    t20_bowl_matches:     statNum(s, "t20", "bowling", "mat"),
    t20_bowl_innings:     statNum(s, "t20", "bowling", "inns"),
    t20_bowl_balls:       statNum(s, "t20", "bowling", "balls"),
    t20_bowl_runs:        statNum(s, "t20", "bowling", "runs"),
    t20_bowl_wickets:     statNum(s, "t20", "bowling", "wkts"),
    t20_bowl_avg:         statNum(s, "t20", "bowling", "avg"),
    t20_bowl_economy:     statNum(s, "t20", "bowling", "econ"),
    t20_bowl_strike_rate: statNum(s, "t20", "bowling", "sr"),
    t20_bowl_5wi:         statNum(s, "t20", "bowling", "5w"),
    // Test batting
    test_bat_matches:     statNum(s, "test", "batting", "mat"),
    test_bat_innings:     statNum(s, "test", "batting", "inns"),
    test_bat_not_outs:    statNum(s, "test", "batting", "no"),
    test_bat_runs:        statNum(s, "test", "batting", "runs"),
    test_bat_highest:     statText(s, "test", "batting", "hs"),
    test_bat_avg:         statNum(s, "test", "batting", "avg"),
    test_bat_balls_faced: statNum(s, "test", "batting", "bf"),
    test_bat_strike_rate: statNum(s, "test", "batting", "sr"),
    test_bat_100s:        statNum(s, "test", "batting", "100"),
    test_bat_50s:         statNum(s, "test", "batting", "50"),
    test_bat_4s:          statNum(s, "test", "batting", "4s"),
    test_bat_6s:          statNum(s, "test", "batting", "6s"),
    // Test bowling
    test_bowl_matches:    statNum(s, "test", "bowling", "mat"),
    test_bowl_innings:    statNum(s, "test", "bowling", "inns"),
    test_bowl_balls:      statNum(s, "test", "bowling", "balls"),
    test_bowl_runs:       statNum(s, "test", "bowling", "runs"),
    test_bowl_wickets:    statNum(s, "test", "bowling", "wkts"),
    test_bowl_avg:        statNum(s, "test", "bowling", "avg"),
    test_bowl_economy:    statNum(s, "test", "bowling", "econ"),
    test_bowl_strike_rate:statNum(s, "test", "bowling", "sr"),
    test_bowl_5wi:        statNum(s, "test", "bowling", "5w"),
    test_bowl_10wi:       statNum(s, "test", "bowling", "10"),
  };
}

// ── Write one player's stats to player_career_stats_master ──
async function writeToMaster(player, flat, poolSource) {
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
      ${player.player_name}, ${player.country}, ${player.cricapi_player_id}, ${poolSource},
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
    ON CONFLICT (player_name, country)
    DO UPDATE SET
      cricapi_player_id     = EXCLUDED.cricapi_player_id,
      player_pool_source    = EXCLUDED.player_pool_source,
      odi_bat_matches       = EXCLUDED.odi_bat_matches,
      odi_bat_innings       = EXCLUDED.odi_bat_innings,
      odi_bat_not_outs      = EXCLUDED.odi_bat_not_outs,
      odi_bat_runs          = EXCLUDED.odi_bat_runs,
      odi_bat_highest       = EXCLUDED.odi_bat_highest,
      odi_bat_avg           = EXCLUDED.odi_bat_avg,
      odi_bat_balls_faced   = EXCLUDED.odi_bat_balls_faced,
      odi_bat_strike_rate   = EXCLUDED.odi_bat_strike_rate,
      odi_bat_100s          = EXCLUDED.odi_bat_100s,
      odi_bat_50s           = EXCLUDED.odi_bat_50s,
      odi_bat_4s            = EXCLUDED.odi_bat_4s,
      odi_bat_6s            = EXCLUDED.odi_bat_6s,
      odi_bowl_matches      = EXCLUDED.odi_bowl_matches,
      odi_bowl_innings      = EXCLUDED.odi_bowl_innings,
      odi_bowl_balls        = EXCLUDED.odi_bowl_balls,
      odi_bowl_runs         = EXCLUDED.odi_bowl_runs,
      odi_bowl_wickets      = EXCLUDED.odi_bowl_wickets,
      odi_bowl_avg          = EXCLUDED.odi_bowl_avg,
      odi_bowl_economy      = EXCLUDED.odi_bowl_economy,
      odi_bowl_strike_rate  = EXCLUDED.odi_bowl_strike_rate,
      odi_bowl_5wi          = EXCLUDED.odi_bowl_5wi,
      t20_bat_matches       = EXCLUDED.t20_bat_matches,
      t20_bat_innings       = EXCLUDED.t20_bat_innings,
      t20_bat_not_outs      = EXCLUDED.t20_bat_not_outs,
      t20_bat_runs          = EXCLUDED.t20_bat_runs,
      t20_bat_highest       = EXCLUDED.t20_bat_highest,
      t20_bat_avg           = EXCLUDED.t20_bat_avg,
      t20_bat_balls_faced   = EXCLUDED.t20_bat_balls_faced,
      t20_bat_strike_rate   = EXCLUDED.t20_bat_strike_rate,
      t20_bat_100s          = EXCLUDED.t20_bat_100s,
      t20_bat_50s           = EXCLUDED.t20_bat_50s,
      t20_bat_4s            = EXCLUDED.t20_bat_4s,
      t20_bat_6s            = EXCLUDED.t20_bat_6s,
      t20_bowl_matches      = EXCLUDED.t20_bowl_matches,
      t20_bowl_innings      = EXCLUDED.t20_bowl_innings,
      t20_bowl_balls        = EXCLUDED.t20_bowl_balls,
      t20_bowl_runs         = EXCLUDED.t20_bowl_runs,
      t20_bowl_wickets      = EXCLUDED.t20_bowl_wickets,
      t20_bowl_avg          = EXCLUDED.t20_bowl_avg,
      t20_bowl_economy      = EXCLUDED.t20_bowl_economy,
      t20_bowl_strike_rate  = EXCLUDED.t20_bowl_strike_rate,
      t20_bowl_5wi          = EXCLUDED.t20_bowl_5wi,
      test_bat_matches      = EXCLUDED.test_bat_matches,
      test_bat_innings      = EXCLUDED.test_bat_innings,
      test_bat_not_outs     = EXCLUDED.test_bat_not_outs,
      test_bat_runs         = EXCLUDED.test_bat_runs,
      test_bat_highest      = EXCLUDED.test_bat_highest,
      test_bat_avg          = EXCLUDED.test_bat_avg,
      test_bat_balls_faced  = EXCLUDED.test_bat_balls_faced,
      test_bat_strike_rate  = EXCLUDED.test_bat_strike_rate,
      test_bat_100s         = EXCLUDED.test_bat_100s,
      test_bat_50s          = EXCLUDED.test_bat_50s,
      test_bat_4s           = EXCLUDED.test_bat_4s,
      test_bat_6s           = EXCLUDED.test_bat_6s,
      test_bowl_matches     = EXCLUDED.test_bowl_matches,
      test_bowl_innings     = EXCLUDED.test_bowl_innings,
      test_bowl_balls       = EXCLUDED.test_bowl_balls,
      test_bowl_runs        = EXCLUDED.test_bowl_runs,
      test_bowl_wickets     = EXCLUDED.test_bowl_wickets,
      test_bowl_avg         = EXCLUDED.test_bowl_avg,
      test_bowl_economy     = EXCLUDED.test_bowl_economy,
      test_bowl_strike_rate = EXCLUDED.test_bowl_strike_rate,
      test_bowl_5wi         = EXCLUDED.test_bowl_5wi,
      test_bowl_10wi        = EXCLUDED.test_bowl_10wi,
      data_source           = 'cricapi',
      last_synced_at        = NOW(),
      updated_at            = NOW()
  `;
}

export default async function handler(req, res) {
  try {
    const source     = String(req.query.source || "all").toLowerCase();
    const playerFilter = req.query.player ? String(req.query.player).trim() : null;

    // ── Source 1: IPL players from cricapi_player_master ──────
    let iplPlayers = [];
    if (source === "all" || source === "ipl") {
      iplPlayers = await sql`
        SELECT cricapi_player_id, player_name, country, 'ipl' AS pool_source
        FROM cricapi_player_master
        ${playerFilter ? sql`WHERE LOWER(player_name) = LOWER(${playerFilter})` : sql``}
        ORDER BY country, player_name
      `;
    }

    // ── Source 2: cricket_player_pool players (SL/WI/etc) ─────
    // Joined to cricsheet_player_mapping where the CricAPI ID was
    // stored by sync-pool-player-cricapi-ids.
    let poolPlayers = [];
    if (source === "all" || source === "pool") {
      poolPlayers = await sql`
        SELECT
          cpm.cricapi_player_id,
          cpp.player_name,
          cpp.country,
          'cricket' AS pool_source
        FROM cricket_player_pool cpp
        JOIN cricsheet_player_mapping cpm
          ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
         AND cpm.country = cpp.country
        WHERE cpp.is_active = TRUE
          AND cpm.cricapi_player_id IS NOT NULL
          AND cpm.mapping_status = 'mapped'
          ${playerFilter ? sql`AND LOWER(cpp.player_name) = LOWER(${playerFilter})` : sql``}
        ORDER BY cpp.country, cpp.player_name
      `;
    }

    const allPlayers = [...iplPlayers, ...poolPlayers];

    if (allPlayers.length === 0) {
      return res.status(200).json({
        success: true,
        message: playerFilter
          ? `No player found matching "${playerFilter}" in the requested source(s).`
          : "No players found. Run sync-pool-player-cricapi-ids first for pool players.",
        total_players: 0,
        results: []
      });
    }

    const results = [];

    for (const player of allPlayers) {
      try {
        const apiData    = await fetchPlayerInfo(player.cricapi_player_id);
        const playerData = apiData.data || apiData;
        const stats      = playerData.stats || [];

        // ── Write to legacy JSON table (backwards compatible) ──
        const battingTest = buildStatsObject(stats, "test", "batting");
        const battingOdi  = buildStatsObject(stats, "odi",  "batting");
        const battingT20  = buildStatsObject(stats, "t20",  "batting") ||
                            buildStatsObject(stats, "t20i", "batting");
        const bowlingTest = buildStatsObject(stats, "test", "bowling");
        const bowlingOdi  = buildStatsObject(stats, "odi",  "bowling");
        const bowlingT20  = buildStatsObject(stats, "t20",  "bowling") ||
                            buildStatsObject(stats, "t20i", "bowling");

        await sql`
          INSERT INTO cricapi_player_career_stats (
            cricapi_player_id, player_name, country,
            batting_test, batting_odi, batting_t20,
            bowling_test, bowling_odi, bowling_t20,
            raw_json, updated_at
          )
          VALUES (
            ${player.cricapi_player_id},
            ${playerData.name || player.player_name},
            ${playerData.country || player.country},
            ${JSON.stringify(battingTest)}, ${JSON.stringify(battingOdi)}, ${JSON.stringify(battingT20)},
            ${JSON.stringify(bowlingTest)}, ${JSON.stringify(bowlingOdi)}, ${JSON.stringify(bowlingT20)},
            ${JSON.stringify(playerData)}, NOW()
          )
          ON CONFLICT (cricapi_player_id)
          DO UPDATE SET
            player_name   = EXCLUDED.player_name,
            country       = EXCLUDED.country,
            batting_test  = EXCLUDED.batting_test,
            batting_odi   = EXCLUDED.batting_odi,
            batting_t20   = EXCLUDED.batting_t20,
            bowling_test  = EXCLUDED.bowling_test,
            bowling_odi   = EXCLUDED.bowling_odi,
            bowling_t20   = EXCLUDED.bowling_t20,
            raw_json      = EXCLUDED.raw_json,
            updated_at    = NOW()
        `;

        // ── Write to new flat-column master table ──────────────
        const flat = buildFlatStats(stats);
        await writeToMaster(
          { player_name: playerData.name || player.player_name,
            country: playerData.country || player.country,
            cricapi_player_id: player.cricapi_player_id },
          flat,
          player.pool_source
        );

        results.push({
          player_name: playerData.name || player.player_name,
          country: playerData.country || player.country,
          pool_source: player.pool_source,
          status: "saved"
        });

      } catch (playerError) {
        results.push({
          player_name: player.player_name,
          country: player.country,
          pool_source: player.pool_source,
          status: "error",
          error: playerError.message
        });
      }
    }

    const saved  = results.filter(r => r.status === "saved").length;
    const errors = results.filter(r => r.status === "error").length;

    return res.status(200).json({
      success: true,
      source,
      player_filter: playerFilter,
      total_players: allPlayers.length,
      saved,
      errors,
      results
    });

  } catch (error) {
    console.error("sync-selected-player-career-stats error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }
}
