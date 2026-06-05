import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

const TARGET_COUNTRIES = ["India", "Afghanistan"];
const TARGET_TEAMS = ["India", "Afghanistan"];

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
    throw new Error(`match_scorecard failed for ${matchId}: ${JSON.stringify(data)}`);
  }

  return data.data;
}

function normalizeTeamName(name) {
  return String(name || "").trim().toLowerCase();
}

function getOpponent(teams, playerCountry) {
  if (!Array.isArray(teams)) return null;

  const opponent = teams.find(
    t => normalizeTeamName(t) !== normalizeTeamName(playerCountry)
  );

  return opponent || null;
}

function detectBattingTeam(inningName, teams) {
  const inning = normalizeTeamName(inningName);

  for (const team of teams || []) {
    if (inning.includes(normalizeTeamName(team))) {
      return team;
    }
  }

  return null;
}

function isOut(dismissalText) {
  return dismissalText && normalizeTeamName(dismissalText) !== "not out";
}

function toNumber(value) {
  if (value === null || value === undefined || value === "") return 0;
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

export default async function handler(req, res) {
  try {
    const selectedPlayers = await sql`
      SELECT cricapi_player_id, player_name, country
      FROM cricapi_player_master
      WHERE country = ANY(${TARGET_COUNTRIES})
    `;

    const playerMap = new Map(
      selectedPlayers.map(p => [p.cricapi_player_id, p])
    );

    const currentMatches = await fetchCurrentMatches();

    const targetMatches = currentMatches.filter(match => {
      const teams = match.teams || [];
      const hasTargetTeam = teams.some(t =>
        TARGET_TEAMS.includes(t)
      );

      return hasTargetTeam && match.matchEnded === true;
    });

    const insertedRows = [];
    const skippedMatches = [];

    for (const match of targetMatches) {
      const alreadySynced = await sql`
        SELECT cricapi_match_id
        FROM cricapi_player_history_synced_matches
        WHERE cricapi_match_id = ${match.id}
        LIMIT 1
      `;

      if (alreadySynced.length > 0) {
        skippedMatches.push({
          match_id: match.id,
          match_name: match.name,
          reason: "already_synced"
        });
        continue;
      }

      const scorecardData = await fetchScorecard(match.id);
      const scorecard = scorecardData.scorecard || [];

      for (const innings of scorecard) {
        const battingTeam = detectBattingTeam(innings.inning, scorecardData.teams);
        const bowlingTeam = getOpponent(scorecardData.teams, battingTeam);

        const battingRows = innings.batting || [];
        const bowlingRows = innings.bowling || [];

        for (const bat of battingRows) {
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
            match_name: scorecardData.name,
            type: "batting"
          });
        }

        for (const bowl of bowlingRows) {
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
            match_name: scorecardData.name,
            type: "bowling"
          });
        }
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
    }

    return res.status(200).json({
      success: true,
      selected_players: selectedPlayers.length,
      target_matches_found: targetMatches.length,
      inserted_or_updated_rows: insertedRows.length,
      insertedRows,
      skippedMatches
    });
  } catch (error) {
    console.error("sync-selected-player-match-history error:", error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
