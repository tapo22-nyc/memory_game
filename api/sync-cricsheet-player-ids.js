import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

function parseCsvLine(line) {
  const parts = line.split(",");
  return {
    identifier: parts[0],
    name: parts[1],
    unique_name: parts[2]
  };
}

function normalize(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/['’]/g, "")
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
  const initials = parts.slice(0, -1).map((p) => p[0]).join("");

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
  if (parts.length === 0) return normalize(fullName);

  return parts[parts.length - 1];
}

function buildCandidates(playerName, searchName) {
  const rawNames = [playerName, searchName].filter(Boolean);
  const candidates = [];

  for (const rawName of rawNames) {
    candidates.push(normalize(rawName));
    candidates.push(initialsSurname(rawName));
    candidates.push(firstInitialSurname(rawName));
    candidates.push(surnameOnly(rawName));
  }

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

function findBestMatch(people, candidates, playerName, searchName) {
  for (const candidate of candidates) {
    const exact =
      people.find((p) => normalize(p.name) === candidate) ||
      people.find((p) => normalize(p.unique_name) === candidate);

    if (exact) {
      return {
        match: exact,
        matched_on: candidate,
        match_type: "exact_candidate"
      };
    }
  }

  const fuzzyMatches = people.filter((p) =>
    candidateInitialSurnameMatch(p.name, playerName) ||
    candidateInitialSurnameMatch(p.unique_name, playerName) ||
    candidateInitialSurnameMatch(p.name, searchName) ||
    candidateInitialSurnameMatch(p.unique_name, searchName)
  );

  const uniqueById = Array.from(
    new Map(fuzzyMatches.map((p) => [p.identifier, p])).values()
  );

  if (uniqueById.length === 1) {
    return {
      match: uniqueById[0],
      matched_on: "surname + first initial",
      match_type: "initial_surname_unique"
    };
  }

  return null;
}

export default async function handler(req, res) {
  try {
    const response = await fetch("https://cricsheet.org/register/people.csv");
    const text = await response.text();

    if (!response.ok) {
      throw new Error(`Cricsheet people.csv failed: ${response.status}`);
    }

    const people = text
      .split("\n")
      .slice(1)
      .filter(Boolean)
      .map(parseCsvLine);

    const players = await sql`
      SELECT
        scp.player_name,
        scp.search_name,
        scp.primary_country AS country,
        cpm.cricapi_player_id
      FROM selected_cricket_players scp
      JOIN cricapi_player_master cpm
        ON scp.search_name = cpm.source_search_name
       AND scp.primary_country = cpm.country
      WHERE scp.is_active = TRUE
      ORDER BY scp.primary_country, scp.player_name
    `;

    const results = [];

    for (const player of players) {
      const candidates = buildCandidates(player.player_name, player.search_name);

      const best = findBestMatch(
        people,
        candidates,
        player.player_name,
        player.search_name
      );

      if (!best) {
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
            ${player.cricapi_player_id},
            NULL,
            'not_found',
            NOW()
          )
          ON CONFLICT (player_name, country)
          DO UPDATE SET
            cricapi_player_id = EXCLUDED.cricapi_player_id,
            cricsheet_player_id = NULL,
            mapping_status = 'not_found',
            updated_at = NOW()
        `;

        results.push({
          player_name: player.player_name,
          search_name: player.search_name,
          country: player.country,
          candidates,
          status: "not_found"
        });

        continue;
      }

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
          ${player.cricapi_player_id},
          ${best.match.identifier},
          'mapped',
          NOW()
        )
        ON CONFLICT (player_name, country)
        DO UPDATE SET
          cricapi_player_id = EXCLUDED.cricapi_player_id,
          cricsheet_player_id = EXCLUDED.cricsheet_player_id,
          mapping_status = 'mapped',
          updated_at = NOW()
      `;

      results.push({
        player_name: player.player_name,
        search_name: player.search_name,
        country: player.country,
        cricsheet_player_id: best.match.identifier,
        matched_name: best.match.name,
        matched_unique_name: best.match.unique_name,
        matched_on: best.matched_on,
        match_type: best.match_type,
        candidates,
        status: "mapped"
      });
    }

    const mappedCount = results.filter((r) => r.status === "mapped").length;
    const notFoundCount = results.filter((r) => r.status === "not_found").length;

    return res.status(200).json({
      success: true,
      source: "selected_cricket_players + cricapi_player_master",
      total_players: players.length,
      mapped_count: mappedCount,
      not_found_count: notFoundCount,
      results
    });
  } catch (error) {
    console.error("sync-cricsheet-player-ids error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
