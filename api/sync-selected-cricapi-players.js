import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

async function searchPlayer(playerName) {
  const url =
    `https://api.cricapi.com/v1/players?apikey=${process.env.CRICAPI_KEY}` +
    `&search=${encodeURIComponent(playerName)}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`CricAPI failed for ${playerName}: ${JSON.stringify(data)}`);
  }

  return data;
}

function pickBestMatch(apiData, expectedName) {
  const players = apiData.data || [];

  if (players.length === 0) return null;

  const exact = players.find(
    (p) => p.name?.toLowerCase() === expectedName.toLowerCase()
  );

  return exact || players[0];
}

export default async function handler(req, res) {
  try {
    const selectedPlayers = await sql`
      SELECT
        player_name,
        search_name,
        primary_country
      FROM selected_cricket_players
      WHERE is_active = TRUE
      ORDER BY primary_country, player_name
    `;

    const results = [];

    for (const player of selectedPlayers) {
      const apiData = await searchPlayer(player.search_name);
      const bestMatch = pickBestMatch(apiData, player.search_name);

      if (!bestMatch) {
        results.push({
          search_name: player.search_name,
          player_name: player.player_name,
          country: player.primary_country,
          status: "not_found"
        });
        continue;
      }

      await sql`
        INSERT INTO cricapi_player_master (
          cricapi_player_id,
          player_name,
          country,
          source_search_name,
          raw_json,
          updated_at
        )
        VALUES (
          ${bestMatch.id},
          ${bestMatch.name},
          ${player.primary_country},
          ${player.search_name},
          ${JSON.stringify(bestMatch)},
          NOW()
        )
        ON CONFLICT (cricapi_player_id)
        DO UPDATE SET
          player_name = EXCLUDED.player_name,
          country = EXCLUDED.country,
          source_search_name = EXCLUDED.source_search_name,
          raw_json = EXCLUDED.raw_json,
          updated_at = NOW()
      `;

      results.push({
        search_name: player.search_name,
        saved_name: bestMatch.name,
        cricapi_player_id: bestMatch.id,
        country: player.primary_country,
        status: "saved"
      });
    }

    return res.status(200).json({
      success: true,
      source: "selected_cricket_players",
      total_players: selectedPlayers.length,
      results
    });
  } catch (error) {
    console.error("sync-selected-cricapi-players error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
