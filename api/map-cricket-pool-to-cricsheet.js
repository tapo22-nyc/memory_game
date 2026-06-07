import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

// ─────────────────────────────────────────────────────────────
// map-cricket-pool-to-cricsheet.js
//
// PURPOSE:
//   SL/WI (and other international) players live in
//   cricket_player_pool, not in selected_cricket_players or
//   cricapi_player_master.  The existing sync-cricsheet-player-ids
//   API only processes players from those IPL tables, so SL/WI
//   players were never mapped and the backfill API skips them.
//
//   This API:
//     1. Reads players from cricket_player_pool
//     2. Downloads Cricsheet's people.csv (the global player registry)
//     3. Matches each player name using the same logic as the
//        existing sync-cricsheet-player-ids API
//     4. Inserts the match into cricsheet_player_mapping so the
//        existing backfill-player-history-from-cricsheet API can
//        pick them up without any further changes
//
//   PLACEHOLDER cricapi_player_id:
//     SL/WI players have no CricAPI ID. The backfill API uses
//     cricapi_player_id as part of the unique key in
//     cricapi_player_match_history. A NULL would break duplicate
//     detection, so we store 'cs_<cricsheet_id>' as a stable
//     placeholder. This never hits the CricAPI service — it is
//     only used as a unique string in our DB.
//
// USAGE (call from browser or curl after deploying):
//   GET /api/map-cricket-pool-to-cricsheet
//       ?countries=SL,WI          (comma-separated, default: SL,WI)
//       &dryRun=true              (preview without writing, default: false)
//
// SAFE TO RE-RUN: uses ON CONFLICT DO UPDATE so existing rows
//   are refreshed, not duplicated.
// ─────────────────────────────────────────────────────────────

// ── Name normalisation (same approach as sync-cricsheet-player-ids) ──

function normalize(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/['']/g, "")
    .replace(/\./g, "")
    .replace(/\s+/g, " ");
}

function nameParts(fullName) {
  return normalize(fullName).split(" ").filter(Boolean);
}

function initialsSurname(fullName) {
  const parts = nameParts(fullName);
  if (parts.length < 2) return normalize(fullName);
  const surname = parts[parts.length - 1];
  const initials = parts.slice(0, -1).map(p => p[0]).join("");
  return `${initials} ${surname}`;
}

function firstInitialSurname(fullName) {
  const parts = nameParts(fullName);
  if (parts.length < 2) return normalize(fullName);
  const surname = parts[parts.length - 1];
  const firstInitial = parts[0][0];
  return `${firstInitial} ${surname}`;
}

function surnameOnly(fullName) {
  const parts = nameParts(fullName);
  return parts.length ? parts[parts.length - 1] : normalize(fullName);
}

function buildCandidates(playerName) {
  const candidates = [
    normalize(playerName),
    initialsSurname(playerName),
    firstInitialSurname(playerName),
    surnameOnly(playerName)
  ];
  return [...new Set(candidates.filter(Boolean))];
}

function candidateInitialSurnameMatch(personName, fullName) {
  const personParts = normalize(personName).split(" ").filter(Boolean);
  const playerParts = nameParts(fullName);
  if (personParts.length < 2 || playerParts.length < 2) return false;
  const personInitials = personParts[0];
  const personSurname = personParts[personParts.length - 1];
  const playerFirstInitial = playerParts[0][0];
  const playerSurname = playerParts[playerParts.length - 1];
  return (
    personSurname === playerSurname &&
    personInitials.startsWith(playerFirstInitial)
  );
}

function findBestMatch(people, candidates, playerName) {
  // Pass 1: exact match on any candidate form
  for (const candidate of candidates) {
    const exact =
      people.find(p => normalize(p.name) === candidate) ||
      people.find(p => normalize(p.unique_name) === candidate);
    if (exact) {
      return { match: exact, matched_on: candidate, match_type: "exact" };
    }
  }

  // Pass 2: initial+surname fuzzy (only if it resolves to exactly one person)
  const fuzzyMatches = people.filter(
    p =>
      candidateInitialSurnameMatch(p.name, playerName) ||
      candidateInitialSurnameMatch(p.unique_name, playerName)
  );
  const uniqueById = Array.from(
    new Map(fuzzyMatches.map(p => [p.identifier, p])).values()
  );
  if (uniqueById.length === 1) {
    return {
      match: uniqueById[0],
      matched_on: "initial+surname",
      match_type: "fuzzy_unique"
    };
  }

  return null;
}

function parseCsvLine(line) {
  const parts = line.split(",");
  return { identifier: parts[0], name: parts[1], unique_name: parts[2] };
}

export default async function handler(req, res) {
  try {
    // ── Parameters ──
    const countriesParam = String(req.query.countries || "SL,WI");
    const countries = countriesParam.split(",").map(c => c.trim().toUpperCase());
    const dryRun = String(req.query.dryRun || "false") === "true";

    // ── Load players from cricket_player_pool ──
    const players = await sql`
      SELECT id, player_name, country, player_type
      FROM cricket_player_pool
      WHERE country = ANY(${countries})
        AND is_active = TRUE
      ORDER BY country, player_name
    `;

    if (players.length === 0) {
      return res.status(200).json({
        success: true,
        message: `No active players found in cricket_player_pool for countries: ${countries.join(", ")}`,
        countries,
        players_found: 0
      });
    }

    // ── Download Cricsheet people.csv ──
    const csvResponse = await fetch("https://cricsheet.org/register/people.csv");
    if (!csvResponse.ok) {
      throw new Error(`Failed to fetch Cricsheet people.csv: ${csvResponse.status}`);
    }
    const csvText = await csvResponse.text();
    const people = csvText
      .split("\n")
      .slice(1)          // skip header row
      .filter(Boolean)
      .map(parseCsvLine);

    // ── Match each player ──
    const results = [];

    for (const player of players) {
      const candidates = buildCandidates(player.player_name);
      const best = findBestMatch(people, candidates, player.player_name);

      if (!best) {
        // Not found — insert with status 'not_found' so we know to fix manually
        if (!dryRun) {
          await sql`
            INSERT INTO cricsheet_player_mapping (
              player_name,
              country,
              cricapi_player_id,
              cricsheet_player_id,
              mapping_status,
              updated_at
            )
            VALUES (
              ${player.player_name},
              ${player.country},
              NULL,
              NULL,
              'not_found',
              NOW()
            )
            ON CONFLICT (player_name, country)
            DO UPDATE SET
              mapping_status = 'not_found',
              cricsheet_player_id = NULL,
              updated_at = NOW()
          `;
        }

        results.push({
          player_name: player.player_name,
          country: player.country,
          player_type: player.player_type,
          status: "not_found",
          candidates_tried: candidates,
          action: dryRun ? "dry_run — no write" : "inserted as not_found — fix manually"
        });
        continue;
      }

      // cricapi_player_id placeholder: 'cs_<cricsheet_id>'
      // This is a stable non-null string that makes the unique key in
      // cricapi_player_match_history work correctly without a real CricAPI ID.
      const placeholderCricapiId = `cs_${best.match.identifier}`;

      if (!dryRun) {
        await sql`
          INSERT INTO cricsheet_player_mapping (
            player_name,
            country,
            cricapi_player_id,
            cricsheet_player_id,
            mapping_status,
            updated_at
          )
          VALUES (
            ${player.player_name},
            ${player.country},
            ${placeholderCricapiId},
            ${best.match.identifier},
            'mapped',
            NOW()
          )
          ON CONFLICT (player_name, country)
          DO UPDATE SET
            cricapi_player_id   = EXCLUDED.cricapi_player_id,
            cricsheet_player_id = EXCLUDED.cricsheet_player_id,
            mapping_status      = 'mapped',
            updated_at          = NOW()
        `;
      }

      results.push({
        player_name: player.player_name,
        country: player.country,
        player_type: player.player_type,
        status: "mapped",
        cricsheet_player_id: best.match.identifier,
        cricapi_player_id_placeholder: placeholderCricapiId,
        matched_name: best.match.name,
        matched_unique_name: best.match.unique_name,
        matched_on: best.matched_on,
        match_type: best.match_type,
        candidates_tried: candidates,
        action: dryRun ? "dry_run — no write" : "inserted into cricsheet_player_mapping"
      });
    }

    const mappedCount   = results.filter(r => r.status === "mapped").length;
    const notFoundCount = results.filter(r => r.status === "not_found").length;

    return res.status(200).json({
      success: true,
      dry_run: dryRun,
      countries,
      total_players: players.length,
      mapped: mappedCount,
      not_found: notFoundCount,
      next_step: notFoundCount > 0
        ? `Fix the ${notFoundCount} not_found players manually using the SQL in sql/sl_wi_history_backfill_steps.sql, then call the backfill API.`
        : "All players mapped. Now call /api/backfill-player-history-from-cricsheet for each format.",
      results
    });

  } catch (error) {
    console.error("map-cricket-pool-to-cricsheet error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }
}
