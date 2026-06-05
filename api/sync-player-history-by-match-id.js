import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

async function fetchScorecard(matchId) {
  const url =
    `https://api.cricapi.com/v1/match_scorecard?apikey=${process.env.CRICAPI_KEY}` +
    `&id=${encodeURIComponent(matchId)}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`match_scorecard failed for ${matchId}: ${JSON.stringify(data)}`);
  }

  return data.data;
}

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function toNumber(value) {
  if (value === null || value === undefined || value === "") return 0;
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function detectBattingTeam(inningName, teams) {
  const inning = normalize(inningName);

  for (const team of teams || []) {
    if (inning.includes(normalize(team))) return team;
  }

  return null;
}

function getOpponent(teams, teamName) {
  if (!Array.isArray(teams)) return null;

  return (
    teams.find(t => normalize(t) !== normalize(teamName)) || null
  );
}

function isOut(dismissalText) {
  return dismissalText && normalize(dismissalText) !== "not out";
}

export default async function handler(req, res) {
  try {
    const matchId = req.query.id;

    if (!matchId) {
      return res.status(400).json({
        success: false,
        error: "Missing match id. Use ?id=MATCH_ID"
      });
    }

    const selectedPlayers = await sql`
      SELECT cricapi_player_id, player_name, country
      FROM cricapi_player_master
    `;

    const playerMap = new Map(
      selectedPlayers.map(p => [p.cricapi_player_id, p])
    );

    const scorecardData = await fetchScorecard(matchId);

    if (!scorecardData.matchEnded) {
      return res.status(200).json({
        success: false,
        message: "Match has not ended yet. Not syncing.",
        match_name: scorecardData.name,
        status: scorecardData.status
      });
    }

    const insertedRows = [];

    for (const innings of scorecardData.scorecard || []) {
      const battingTeam = detectBattingTeam(innings.inning, scorecardData.teams);
      const bowlingTeam = getOpponent(scorecardData.teams, battingTeam);

      for (const bat of innings.batting || []) {
        const batterId = bat.batsman?.id;
        const selectedPlayer = playerMap.get(batterId);

        if (!selectedPlayer) continue;

        const dismissalText = bat["dismissal-text"] || null;

        await sql`
          INSERT INTO cricapi_player_match_history (
            cricapi_match_id,
            cricapi_player_id,
            player_name,
            country,
            match_name,
            match_date,
            match_type,
            team,
            opponent,
            venue,
            runs,
            balls,
            fours,
            sixes,
            strike_rate,
            dismissal_info,
            dismissal_type,
            dismissed_by_bowler,
            dismissed_by_fielder,
            is_out,
            raw_batting_json,
            raw_scorecard_json,
            updated_at
          )
          VALUES (
            ${scorecardData.id},
            ${batterId},
            ${selectedPlayer.player_name},
            ${selectedPlayer.country},
            ${scorecardData.name},
            ${scorecardData.date},
            ${scorecardData.matchType},
            ${battingTeam},
            ${bowlingTeam},
            ${scorecardData.venue},
            ${toNumber(bat.r)},
            ${toNumber(bat.b)},
            ${toNumber(bat["4s"])},
            ${toNumber(bat["6s"])},
            ${toNumber(bat.sr)},
            ${dismissalText},
            ${bat.dismissal || null},
            ${bat.bowler?.name || null},
            ${bat.catcher?.name || null},
            ${isOut(dismissalText)},
            ${JSON.stringify(bat)},
            ${JSON.stringify(scorecardData)},
            NOW()
          )
          ON CONFLICT (cricapi_match_id, cricapi_player_id)
          DO UPDATE SET
            player_name = EXCLUDED.player_name,
            country = EXCLUDED.country,
            match_name = EXCLUDED.match_name,
            match_date = EXCLUDED.match_date,
            match_type = EXCLUDED.match_type,
            team = EXCLUDED.team,
            opponent = EXCLUDED.opponent,
            venue = EXCLUDED.venue,
            runs = EXCLUDED.runs,
            balls = EXCLUDED.balls,
            fours = EXCLUDED.fours,
            sixes = EXCLUDED.sixes,
            strike_rate = EXCLUDED.strike_rate,
            dismissal_info = EXCLUDED.dismissal_info,
            dismissal_type = EXCLUDED.dismissal_type,
            dismissed_by_bowler = EXCLUDED.dismissed_by_bowler,
            dismissed_by_fielder = EXCLUDED.dismissed_by_fielder,
            is_out = EXCLUDED.is_out,
            raw_batting_json = EXCLUDED.raw_batting_json,
            raw_scorecard_json = EXCLUDED.raw_scorecard_json,
            updated_at = NOW()
        `;

        insertedRows.push({
          player_name: selectedPlayer.player_name,
          type: "batting",
          runs: bat.r,
          dismissal: dismissalText
        });
      }

      for (const bowl of innings.bowling || []) {
        const bowlerId = bowl.bowler?.id;
        const selectedPlayer = playerMap.get(bowlerId);

        if (!selectedPlayer) continue;

        await sql`
          INSERT INTO cricapi_player_match_history (
            cricapi_match_id,
            cricapi_player_id,
            player_name,
            country,
            match_name,
            match_date,
            match_type,
            team,
            opponent,
            venue,
            overs,
            maidens,
            runs_conceded,
            wickets,
            economy,
            raw_bowling_json,
            raw_scorecard_json,
            updated_at
          )
          VALUES (
            ${scorecardData.id},
            ${bowlerId},
            ${selectedPlayer.player_name},
            ${selectedPlayer.country},
            ${scorecardData.name},
            ${scorecardData.date},
            ${scorecardData.matchType},
            ${bowlingTeam},
            ${battingTeam},
            ${scorecardData.venue},
            ${toNumber(bowl.o)},
            ${toNumber(bowl.m)},
            ${toNumber(bowl.r)},
            ${toNumber(bowl.w)},
            ${toNumber(bowl.eco)},
            ${JSON.stringify(bowl)},
            ${JSON.stringify(scorecardData)},
            NOW()
          )
          ON CONFLICT (cricapi_match_id, cricapi_player_id)
          DO UPDATE SET
            player_name = EXCLUDED.player_name,
            country = EXCLUDED.country,
            match_name = EXCLUDED.match_name,
            match_date = EXCLUDED.match_date,
            match_type = EXCLUDED.match_type,
            team = COALESCE(cricapi_player_match_history.team, EXCLUDED.team),
            opponent = COALESCE(cricapi_player_match_history.opponent, EXCLUDED.opponent),
            venue = EXCLUDED.venue,
            overs = EXCLUDED.overs,
            maidens = EXCLUDED.maidens,
            runs_conceded = EXCLUDED.runs_conceded,
            wickets = EXCLUDED.wickets,
            economy = EXCLUDED.economy,
            raw_bowling_json = EXCLUDED.raw_bowling_json,
            raw_scorecard_json = EXCLUDED.raw_scorecard_json,
            updated_at = NOW()
        `;

        insertedRows.push({
          player_name: selectedPlayer.player_name,
          type: "bowling",
          overs: bowl.o,
          wickets: bowl.w
        });
      }
    }

    return res.status(200).json({
      success: true,
      match_name: scorecardData.name,
      match_type: scorecardData.matchType,
      match_date: scorecardData.date,
      selected_players_checked: selectedPlayers.length,
      inserted_or_updated_rows: insertedRows.length,
      insertedRows
    });
  } catch (error) {
    console.error("sync-player-history-by-match-id error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
