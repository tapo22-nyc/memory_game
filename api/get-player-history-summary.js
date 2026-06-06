import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

function toNumber(value) {
  if (value === null || value === undefined) return 0;
  const num = Number(value);
  return Number.isNaN(num) ? 0 : num;
}

function summarizeMatch(rows) {
  const first = rows[0];

  const battingRows = rows.filter(r => toNumber(r.balls) > 0 && toNumber(r.overs) === 0);
  const bowlingRows = rows.filter(r => toNumber(r.overs) > 0);

  return {
    cricapi_player_id: first.cricapi_player_id,
    cricsheet_player_id: first.cricsheet_player_id,
    player_name: first.player_name,
    match_id: first.source_match_id,
    match_name: first.match_name,
    match_date: first.match_date,
    match_type: first.match_type,
    opponent: first.opponent,
    venue: first.venue,

    batting: battingRows.map(r => ({
      innings_number: r.innings_number,
      runs: toNumber(r.runs),
      balls: toNumber(r.balls),
      fours: toNumber(r.fours),
      sixes: toNumber(r.sixes),
      strike_rate: r.strike_rate,
      dismissal_type: r.dismissal_type,
      dismissed_by_bowler: r.dismissed_by_bowler,
      dismissed_by_fielder: r.dismissed_by_fielder,
      is_out: r.is_out
    })),

    bowling: bowlingRows.map(r => ({
      innings_number: r.innings_number,
      overs: r.overs,
      balls: toNumber(r.balls),
      runs_conceded: toNumber(r.runs_conceded),
      wickets: toNumber(r.wickets),
      economy: r.economy
    })),

    totals: {
      total_runs: battingRows.reduce((sum, r) => sum + toNumber(r.runs), 0),
      total_balls: battingRows.reduce((sum, r) => sum + toNumber(r.balls), 0),
      total_fours: battingRows.reduce((sum, r) => sum + toNumber(r.fours), 0),
      total_sixes: battingRows.reduce((sum, r) => sum + toNumber(r.sixes), 0),
      total_wickets: bowlingRows.reduce((sum, r) => sum + toNumber(r.wickets), 0),
      total_runs_conceded: bowlingRows.reduce(
        (sum, r) => sum + toNumber(r.runs_conceded),
        0
      )
    }
  };
}

export default async function handler(req, res) {
  try {
    const player = String(req.query.player || "").trim();
    const format = String(req.query.format || "test").trim().toLowerCase();
    const limit = Number(req.query.limit || 5);

    if (!player) {
      return res.status(400).json({
        success: false,
        error: "Missing player. Use ?player=Virat%20Kohli&format=test"
      });
    }

    const rows = await sql`
      SELECT *
      FROM (
        SELECT DISTINCT ON (
          source_match_id,
          cricapi_player_id,
          innings_number,
          batting_team,
          bowling_team,
          runs,
          balls,
          wickets,
          overs
        )
          source_match_id,
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
        ORDER BY
          source_match_id,
          cricapi_player_id,
          innings_number,
          batting_team,
          bowling_team,
          runs,
          balls,
          wickets,
          overs,
          match_date DESC
      ) x
      ORDER BY match_date DESC, innings_number ASC
    `;

    const grouped = new Map();

    for (const row of rows) {
      if (!grouped.has(row.source_match_id)) {
        grouped.set(row.source_match_id, []);
      }

      grouped.get(row.source_match_id).push(row);
    }

    const summaries = Array.from(grouped.values())
      .map(matchRows => summarizeMatch(matchRows))
      .sort((a, b) => new Date(b.match_date) - new Date(a.match_date))
      .slice(0, limit);

    return res.status(200).json({
      success: true,
      player,
      format,
      matches_returned: summaries.length,
      matches: summaries
    });
  } catch (error) {
    console.error("get-player-history-summary error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
