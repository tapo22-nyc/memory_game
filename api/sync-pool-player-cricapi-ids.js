import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

// ─────────────────────────────────────────────────────────────
// sync-pool-player-cricapi-ids.js
//
// PURPOSE:
//   Before career stats can be fetched from CricAPI, we need
//   each player's CricAPI player ID. IPL players already have
//   this via cricapi_player_master. SL/WI players in
//   cricket_player_pool do not.
//
//   This API:
//     1. Reads active players from cricket_player_pool
//     2. Searches CricAPI /v1/players?search=<name> for each
//     3. Picks the best match by name + country
//     4. Stores the cricapi_player_id in cricsheet_player_mapping
//        so sync-selected-player-career-stats.js can find it
//
// SAFE TO RE-RUN: ON CONFLICT DO UPDATE refreshes existing rows.
//
// USAGE:
//   GET /api/sync-pool-player-cricapi-ids
//       ?countries=SL,WI          (comma-separated, default: SL,WI)
//       &dryRun=true              (preview matches without writing)
//
// COST: one CricAPI search call per player. With 24 SL+WI
//   players this uses ~24 of your monthly API credits.
// ─────────────────────────────────────────────────────────────

// Maps cricket_player_pool country codes → CricAPI country names
const COUNTRY_MAP = {
  SL:  ["Sri Lanka", "sri lanka"],
  WI:  ["West Indies", "west indies"],
  ENG: ["England", "england"],
  NZL: ["New Zealand", "new zealand"],
  IND: ["India", "india"],
  AUS: ["Australia", "australia"],
  PAK: ["Pakistan", "pakistan"],
  SA:  ["South Africa", "south africa"],
  BAN: ["Bangladesh", "bangladesh"],
  ZIM: ["Zimbabwe", "zimbabwe"],
};

function normalize(str) {
  return String(str || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function countryMatches(cricapiCountry, poolCountry) {
  const aliases = COUNTRY_MAP[poolCountry?.toUpperCase()] || [];
  return aliases.some(a => normalize(cricapiCountry) === normalize(a));
}

// Score a CricAPI search result against our player.
// Higher = better match. Returns null if clearly wrong player.
function scoreMatch(candidate, player) {
  const candName = normalize(candidate.name || "");
  const poolName = normalize(player.player_name);

  // Country must match — discard wrong-country results immediately
  if (!countryMatches(candidate.country, player.country)) return null;

  if (candName === poolName) return 100;                    // exact name match
  if (candName.includes(poolName) || poolName.includes(candName)) return 80;

  // Partial: last name matches
  const poolLast = poolName.split(" ").pop();
  const candLast = candName.split(" ").pop();
  if (poolLast && candLast && poolLast === candLast) return 50;

  return 10; // country matched but name did not
}

async function searchCricAPI(playerName) {
  const url =
    `https://api.cricapi.com/v1/players` +
    `?apikey=${process.env.CRICAPI_KEY}` +
    `&search=${encodeURIComponent(playerName)}&offset=0`;

  const res = await fetch(url);
  const data = await res.json();

  if (!res.ok || data.status === "failure") {
    throw new Error(`CricAPI search failed for "${playerName}": ${data.reason || res.status}`);
  }

  return Array.isArray(data.data) ? data.data : [];
}

export default async function handler(req, res) {
  try {
    const countriesParam = String(req.query.countries || "SL,WI");
    const countries = countriesParam.split(",").map(c => c.trim().toUpperCase());
    const dryRun = String(req.query.dryRun || "false") === "true";

    // Load pool players that don't already have a confirmed CricAPI mapping
    const players = await sql`
      SELECT cpp.id, cpp.player_name, cpp.country, cpp.player_type
      FROM cricket_player_pool cpp
      LEFT JOIN cricsheet_player_mapping cpm
             ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
            AND cpm.country = cpp.country
      WHERE cpp.country = ANY(${countries})
        AND cpp.is_active = TRUE
        AND (
          cpm.cricapi_player_id IS NULL          -- never mapped
          OR cpm.mapping_status != 'mapped'      -- previously failed
        )
      ORDER BY cpp.country, cpp.player_name
    `;

    if (players.length === 0) {
      return res.status(200).json({
        success: true,
        message: "All players already have CricAPI IDs. Nothing to do.",
        countries,
        dryRun
      });
    }

    const results = [];

    for (const player of players) {
      try {
        const candidates = await searchCricAPI(player.player_name);

        // Score every candidate and pick the best
        let bestScore = -1;
        let bestCandidate = null;

        for (const c of candidates) {
          const score = scoreMatch(c, player);
          if (score !== null && score > bestScore) {
            bestScore = score;
            bestCandidate = c;
          }
        }

        if (!bestCandidate || bestScore < 50) {
          // No good match found
          if (!dryRun) {
            await sql`
              INSERT INTO cricsheet_player_mapping (
                player_name, country, cricapi_player_id,
                cricsheet_player_id, mapping_status, updated_at
              )
              VALUES (
                ${player.player_name}, ${player.country},
                NULL, NULL, 'not_found', NOW()
              )
              ON CONFLICT (player_name, country)
              DO UPDATE SET
                mapping_status = 'not_found',
                cricapi_player_id = NULL,
                updated_at = NOW()
            `;
          }

          results.push({
            player_name: player.player_name,
            country: player.country,
            status: "not_found",
            candidates_returned: candidates.length,
            note: "No confident match. Add the CricAPI ID manually via the SQL fix in the guide."
          });
          continue;
        }

        if (!dryRun) {
          await sql`
            INSERT INTO cricsheet_player_mapping (
              player_name, country, cricapi_player_id,
              cricsheet_player_id, mapping_status, updated_at
            )
            VALUES (
              ${player.player_name}, ${player.country},
              ${bestCandidate.id}, NULL, 'mapped', NOW()
            )
            ON CONFLICT (player_name, country)
            DO UPDATE SET
              cricapi_player_id = EXCLUDED.cricapi_player_id,
              mapping_status    = 'mapped',
              updated_at        = NOW()
          `;
        }

        results.push({
          player_name: player.player_name,
          country: player.country,
          status: "mapped",
          cricapi_player_id: bestCandidate.id,
          cricapi_name: bestCandidate.name,
          cricapi_country: bestCandidate.country,
          match_score: bestScore,
          dry_run: dryRun
        });

      } catch (playerErr) {
        results.push({
          player_name: player.player_name,
          country: player.country,
          status: "error",
          error: playerErr.message
        });
      }
    }

    const mapped   = results.filter(r => r.status === "mapped").length;
    const notFound = results.filter(r => r.status === "not_found").length;
    const errors   = results.filter(r => r.status === "error").length;

    return res.status(200).json({
      success: true,
      dry_run: dryRun,
      countries,
      total_players_checked: players.length,
      mapped,
      not_found: notFound,
      errors,
      next_step: notFound > 0
        ? `Manually fix ${notFound} players — see sql/player_career_stats_master_setup.sql for the UPDATE template, then re-run sync-selected-player-career-stats.`
        : "All mapped. Call /api/sync-selected-player-career-stats to fetch career stats.",
      results
    });

  } catch (error) {
    console.error("sync-pool-player-cricapi-ids error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }
}
