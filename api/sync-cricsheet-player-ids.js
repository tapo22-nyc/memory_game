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
  return String(value || "").trim().toLowerCase();
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
      SELECT player_name, country, cricapi_player_id
      FROM cricsheet_player_mapping
      ORDER BY country, player_name
    `;

    const results = [];

    for (const player of players) {
      const exact =
        people.find(p => normalize(p.name) === normalize(player.player_name)) ||
        people.find(p => normalize(p.unique_name) === normalize(player.player_name));

      if (!exact) {
        results.push({
          player_name: player.player_name,
          country: player.country,
          status: "not_found"
        });
        continue;
      }

      await sql`
        UPDATE cricsheet_player_mapping
        SET
          cricsheet_player_id = ${exact.identifier},
          updated_at = NOW()
        WHERE player_name = ${player.player_name}
          AND country = ${player.country}
      `;

      results.push({
        player_name: player.player_name,
        country: player.country,
        cricsheet_player_id: exact.identifier,
        matched_name: exact.name,
        status: "mapped"
      });
    }

    return res.status(200).json({
      success: true,
      total_players: players.length,
      results
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
