import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

async function fetchPlayerInfo(playerId) {
  const url =
    `https://api.cricapi.com/v1/players_info?apikey=${process.env.CRICAPI_KEY}` +
    `&id=${encodeURIComponent(playerId)}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`CricAPI player info failed for ${playerId}: ${JSON.stringify(data)}`);
  }

  return data;
}

function findStat(statsArray, format, statType) {
  if (!Array.isArray(statsArray)) return null;

  return statsArray.find(item => {
    const fn = String(item.fn || item.format || "").toLowerCase();
    const matchtype = String(item.matchtype || item.matchType || "").toLowerCase();
    const type = String(item.type || item.category || "").toLowerCase();

    return (
      (fn.includes(format) || matchtype.includes(format)) &&
      type.includes(statType)
    );
  }) || null;
}

export default async function handler(req, res) {
  try {
    const players = await sql`
      SELECT cricapi_player_id, player_name, country
      FROM cricapi_player_master
      ORDER BY country, player_name
    `;

    const results = [];

    for (const player of players) {
      try {
        const apiData = await fetchPlayerInfo(player.cricapi_player_id);
        const playerData = apiData.data || apiData;

        const stats = playerData.stats || [];

        const battingTest = findStat(stats, "test", "batting");
        const battingOdi = findStat(stats, "odi", "batting");
        const battingT20 = findStat(stats, "t20", "batting");

        const bowlingTest = findStat(stats, "test", "bowling");
        const bowlingOdi = findStat(stats, "odi", "bowling");
        const bowlingT20 = findStat(stats, "t20", "bowling");

        await sql`
          INSERT INTO cricapi_player_career_stats (
            cricapi_player_id,
            player_name,
            country,
            batting_test,
            batting_odi,
            batting_t20,
            bowling_test,
            bowling_odi,
            bowling_t20,
            raw_json,
            updated_at
          )
          VALUES (
            ${player.cricapi_player_id},
            ${player.player_name},
            ${player.country},
            ${JSON.stringify(battingTest)},
            ${JSON.stringify(battingOdi)},
            ${JSON.stringify(battingT20)},
            ${JSON.stringify(bowlingTest)},
            ${JSON.stringify(bowlingOdi)},
            ${JSON.stringify(bowlingT20)},
            ${JSON.stringify(playerData)},
            NOW()
          )
          ON CONFLICT (cricapi_player_id)
          DO UPDATE SET
            player_name = EXCLUDED.player_name,
            country = EXCLUDED.country,
            batting_test = EXCLUDED.batting_test,
            batting_odi = EXCLUDED.batting_odi,
            batting_t20 = EXCLUDED.batting_t20,
            bowling_test = EXCLUDED.bowling_test,
            bowling_odi = EXCLUDED.bowling_odi,
            bowling_t20 = EXCLUDED.bowling_t20,
            raw_json = EXCLUDED.raw_json,
            updated_at = NOW()
        `;

        results.push({
          player_name: player.player_name,
          cricapi_player_id: player.cricapi_player_id,
          status: "saved"
        });
      } catch (playerError) {
        results.push({
          player_name: player.player_name,
          cricapi_player_id: player.cricapi_player_id,
          status: "error",
          error: playerError.message
        });
      }
    }

    return res.status(200).json({
      success: true,
      total_players: players.length,
      results
    });
  } catch (error) {
    console.error("sync-selected-player-career-stats error:", error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
