import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

const SELECTED_PLAYERS = [
  { search_name: "Abhishek Sharma", country: "India" },
  { search_name: "Akash Deep", country: "India" },
  { search_name: "Arshdeep Singh", country: "India" },
  { search_name: "Axar Patel", country: "India" },
  { search_name: "Devdutt Padikkal", country: "India" },
  { search_name: "Dhruv Jurel", country: "India" },
  { search_name: "Harshit Rana", country: "India" },
  { search_name: "Ishan Kishan", country: "India" },
  { search_name: "Jasprit Bumrah", country: "India" },
  { search_name: "KL Rahul", country: "India" },
  { search_name: "Kuldeep Yadav", country: "India" },
  { search_name: "Mohammed Siraj", country: "India" },
  { search_name: "Mukesh Kumar", country: "India" },
  { search_name: "Nitish Kumar Reddy", country: "India" },
  { search_name: "Prasidh Krishna", country: "India" },
  { search_name: "Prince Yadav", country: "India" },
  { search_name: "Ravi Bishnoi", country: "India" },
  { search_name: "Ravindra Jadeja", country: "India" },
  { search_name: "Rishabh Pant", country: "India" },
  { search_name: "Rohit Sharma", country: "India" },
  { search_name: "Sai Sudharsan", country: "India" },
  { search_name: "Sanju Samson", country: "India" },
  { search_name: "Sarfaraz Khan", country: "India" },
  { search_name: "Shivam Dube", country: "India" },
  { search_name: "Shreyas Iyer", country: "India" },
  { search_name: "Shubman Gill", country: "India" },
  { search_name: "Tilak Varma", country: "India" },
  { search_name: "Vaibhav Suryavanshi", country: "India" },
  { search_name: "Varun Chakravarthy", country: "India" },
  { search_name: "Virat Kohli", country: "India" },
  { search_name: "Washington Sundar", country: "India" },
  { search_name: "Yashasvi Jaiswal", country: "India" }
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
    (p) => p.name?.toLowerCase() === expectedName.toLowerCase()
  );

  return exact || players[0];
}

export default async function handler(req, res) {
  try {
    const results = [];

    for (const player of SELECTED_PLAYERS) {
      const apiData = await searchPlayer(player.search_name);
      const bestMatch = pickBestMatch(apiData, player.search_name);

      if (!bestMatch) {
        results.push({
          search_name: player.search_name,
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
