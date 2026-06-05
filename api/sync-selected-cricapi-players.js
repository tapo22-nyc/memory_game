import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

const SELECTED_PLAYERS = [
  { name: "Shubman Gill", country: "India" },
  { name: "KL Rahul", country: "India" },
  { name: "Yashasvi Jaiswal", country: "India" },
  { name: "Mohammed Siraj", country: "India" },
  { name: "Dhruv Jurel", country: "India" },
  { name: "Kuldeep Yadav", country: "India" },

  { name: "Hashmatullah Shahidi", country: "Afghanistan" },
  { name: "Abdul Malik", country: "Afghanistan" },
  { name: "Afsar Zazai", country: "Afghanistan" },
  { name: "Azmatullah Omarzai", country: "Afghanistan" },
  { name: "Rahmanullah Gurbaz", country: "Afghanistan" },
  { name: "Qais Ahmad", country: "Afghanistan" }
];

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
    p => p.name?.toLowerCase() === expectedName.toLowerCase()
  );

  return exact || players[0];
}

export default async function handler(req, res) {
  try {
    const results = [];

    for (const player of SELECTED_PLAYERS) {
      const apiData = await searchPlayer(player.name);
      const bestMatch = pickBestMatch(apiData, player.name);

      if (!bestMatch) {
        results.push({
          search_name: player.name,
          country: player.country,
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
          ${player.country},
          ${player.name},
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
        search_name: player.name,
        saved_name: bestMatch.name,
        cricapi_player_id: bestMatch.id,
        country: player.country,
        status: "saved"
      });
    }

    return res.status(200).json({
      success: true,
      total_players: SELECTED_PLAYERS.length,
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
