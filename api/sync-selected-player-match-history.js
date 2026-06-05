import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

const TARGET_COUNTRIES = ["India", "Afghanistan"];

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function isTargetTeamMatch(match) {
  const teams = match.teams || [];
  return teams.some(team =>
    TARGET_COUNTRIES.some(country => normalize(team) === normalize(country))
  );
}

function getOpponent(teams, playerCountry) {
  if (!Array.isArray(teams)) return null;
  return teams.find(team => normalize(team) !== normalize(playerCountry)) || null;
}

async function fetchCurrentMatches() {
  const url =
    `https://api.cricapi.com/v1/currentMatches?apikey=${process.env.CRICAPI_KEY}` +
    `&offset=0`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`currentMatches failed: ${JSON.stringify(data)}`);
  }

  return data.data || [];
}

async function fetchScorecard(matchId) {
  const url =
    `https://api.cricapi.com/v1/match_scorecard?apikey=${process.env.CRICAPI_KEY}` +
    `&id=${encodeURIComponent(matchId)}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`scorecard failed for ${matchId}: ${JSON.stringify(data)}`);
  }

  return data.data;
}

function findPlayerBatting(scorecard, playerId) {
  for (const innings of scorecard || []) {
    for (const row of innings.batting || []) {
      if (row.batsman?.id === playerId) {
        return {
          innings_name: innings.inning || null,
          row
        };
      }
    }
  }

  return {
    innings_name: null,
    row: null
  };
}

function findPlayerBowling(scorecard, playerId) {
  for (const innings of scorecard || []) {
    for (const row of innings.bowling || []) {
      if (row.bowler?.id === playerId) {
        return {
          innings_name: innings.inning || null,
          row
        };
      }
    }
  }

  return {
    innings_name: null,
    row: null
  };
}

function isOutFromBattingRow(row) {
  if (!row) return false;
  const text = normalize(row["dismissal-text"]);
  return text && text !== "not out";
}

export default async function handler(req, res) {
  try {
    const selectedPlayers = await sql`
      SELECT cricapi_player_id, player_name, country
      FROM cricapi_player_master
      WHERE country = ANY(${TARGET_COUNTRIES})
      ORDER BY country, player_name
    `;

    const playerIds = new Set(selectedPlayers.map(p => p.cricapi_player_id));

    const currentMatches = await fetchCurrentMatches();

    const completedTargetMatches = currentMatches.filter(match =>
      match.matchEnded === true &&
      match.fantasyEnabled === true &&
      isTargetTeamMatch(match)
    );

    const results = [];

    for (const match of completedTargetMatches) {
      const scorecardData = await fetchScorecard(match.id);
      const scorecard = scorecardData.scorecard || [];

      let insertedOrUpdated = 0;

      for (const player of selectedPlayers) {
        const batting = findPlayerBatting(scorecard, player.cricapi_player_id);
        const bowling = findPlayerBowling(scorecard, player.cricapi_player_id);

        if (!batting.row && !bowling.row) {
          continue;
        }

        const battingRow = batting.row;
        const bowlingRow = bowling.row;

        const opponent = getOpponent(scorecardData.teams, player.country);

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

            overs,
            maidens,
            runs_conceded,
            wickets,
            economy,

            dismissal_info,
            dismissal_type,
            dismissed_by_bowler,
            dismissed_by_fielder,
            is_out,

            raw_batting_json,
            raw_bowling_json,
            raw_scorecard_json,
            updated_at
          )
          VALUES (
            ${scorecardData.id},
            ${player.cricapi_player_id},
            ${player.player_name},
            ${player.country},

            ${scorecardData.name},
            ${scorecardData.date},
            ${scorecardData.matchType},
            ${player.country},
            ${opponent},
            ${scorecardData.venue},

            ${battingRow?.r || 0},
            ${battingRow?.b || 0},
            ${battingRow?.["4s"] || 0},
            ${battingRow?.["6s"] || 0},
            ${battingRow?.sr || 0},

            ${bowlingRow?.o || 0},
            ${bowlingRow?.m || 0},
            ${bowlingRow?.r || 0},
            ${bowlingRow?.w || 0},
            ${bowlingRow?.eco || 0},

            ${battingRow?.["dismissal-text"] || null},
            ${battingRow?.dismissal || null},
            ${battingRow?.bowler?.name || null},
            ${battingRow?.catcher?.name || null},
            ${isOutFromBattingRow(battingRow)},

            ${JSON.stringify(battingRow || null)},
            ${JSON.stringify(bowlingRow || null)},
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

            overs = EXCLUDED.overs,
            maidens = EXCLUDED.maidens,
            runs_conceded = EXCLUDED.runs_conceded,
            wickets = EXCLUDED.wickets,
            economy = EXCLUDED.economy,

            dismissal_info = EXCLUDED.dismissal_info,
            dismissal_type = EXCLUDED.dismissal_type,
            dismissed_by_bowler = EXCLUDED.dismissed_by_bowler,
            dismissed_by_fielder = EXCLUDED.dismissed_by_fielder,
            is_out = EXCLUDED.is_out,

            raw_batting_json = EXCLUDED.raw_batting_json,
            raw_bowling_json = EXCLUDED.raw_bowling_json,
            raw_scorecard_json = EXCLUDED.raw_scorecard_json,
            updated_at = NOW()
        `;

        insertedOrUpdated++;
      }

      await sql`
        INSERT INTO cricapi_player_history_synced_matches (
          cricapi_match_id,
          match_name,
          match_type,
          match_date,
          teams,
          status,
          raw_json,
          synced_at
        )
        VALUES (
          ${scorecardData.id},
          ${scorecardData.name},
          ${scorecardData.matchType},
          ${scorecardData.date},
          ${scorecardData.teams},
          ${scorecardData.status},
          ${JSON.stringify(scorecardData)},
          NOW()
        )
        ON CONFLICT (cricapi_match_id)
        DO UPDATE SET
          status = EXCLUDED.status,
          raw_json = EXCLUDED.raw_json,
          synced_at = NOW()
      `;

      results.push({
        match_id
