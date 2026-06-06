import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const player = String(req.query.player || "").trim();
    const format = String(req.query.format || "test").trim().toLowerCase();

    if (!player) {
      return res.status(400).json({
        success: false,
        error: "Missing player. Use ?player=Virat%20Kohli&format=test"
      });
    }

    const rows = await sql`
      SELECT
        cricapi_player_id,
        cricsheet_player_id,
        player_name,
        match_name,
        match_date,
        match_type,
        opponent,
        venue,
        innings_number,
        batting_team,
        bowling_team,
        runs,
        balls,
        fours,
        sixes,
        strike_rate,
        dismissal_type,
        dismissed_by_bowler,
        dismissed_by_fielder,
        is_out,
        overs,
        runs_conceded,
        wickets,
        economy
      FROM cricapi_player_match_history
      WHERE LOWER(player_name) = LOWER(${player})
        AND match_type = ${format}
      ORDER BY match_date DESC, innings_number ASC
      LIMIT 20
    `;

    return res.status(200).json({
      success: true,
      player,
      format,
      rows_returned: rows.length,
      rows
    });
  } catch (error) {
    console.error("debug-player-history-summary error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
