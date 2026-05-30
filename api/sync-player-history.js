const { Pool } = require("pg");
const { getTeamLastFiveBattingRows } = require("../services/player-history-service");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

module.exports = async function handler(req, res) {
  try {
    const cricapiKey = process.env.CRICAPI_KEY;

    const matchIds = [
      "ab13f9a8-3660-4706-91d2-c1363810415d",
      "cae89dea-04b5-4b01-85c9-e0c05419fa4f",
      "fd660ab1-c4bf-4c0f-b1b9-7232361cd1e8",
      "166633a2-cecb-4cf3-a984-78dc898b5345",
      "9413d7dd-bf8e-49f6-8ce7-91faf29a0115"
    ];

    const rows = await getTeamLastFiveBattingRows(
      cricapiKey,
      matchIds,
      "Gujarat Titans"
    );

    for (const row of rows) {
      await pool.query(
        `
        INSERT INTO gt_batsman_last_5_innings
        (
          cricapi_match_id,
          match_name,
          match_date,
          team_name,
          player_cricapi_id,
          player_name,
          runs,
          balls,
          fours,
          sixes,
          strike_rate
        )
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
        ON CONFLICT (cricapi_match_id, player_cricapi_id)
        DO UPDATE SET
          runs = EXCLUDED.runs,
          balls = EXCLUDED.balls,
          fours = EXCLUDED.fours,
          sixes = EXCLUDED.sixes,
          strike_rate = EXCLUDED.strike_rate
        `,
        [
          row.cricapi_match_id,
          row.match_name,
          row.match_date,
          row.team_name,
          row.player_cricapi_id,
          row.player_name,
          row.runs,
          row.balls,
          row.fours,
          row.sixes,
          row.strike_rate
        ]
      );
    }

    res.status(200).json({
      success: true,
      inserted_rows: rows.length
    });
  } catch (error) {
    console.error("sync-player-history error:", error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
