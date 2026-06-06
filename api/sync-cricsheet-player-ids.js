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
    .replace(/\s+/g, " ");
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
      const exact =
        people.find(p => normalize(p.name) === normalize(player.player_name)) ||
        people.find(p => normalize(p.unique_name) === normalize(player.player_name)) ||
        people.find(p => normalize(p.name) === normalize(player.search_name)) ||
        people.find(p => normalize(p.unique_name) === normalize(player.search_name));

      if (!exact) {
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
          ${exact.identifier},
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
        cricsheet_player_id: exact.identifier,
        matched_name: exact.name,
        status: "mapped"
      });
    }

    return res.status(200).json({
      success: true,
      source: "selected_cricket_players + cricapi_player_master",
      total_players: players.length,
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
