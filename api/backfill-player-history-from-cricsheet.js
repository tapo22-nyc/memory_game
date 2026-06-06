import { neon } from "@neondatabase/serverless";
import JSZip from "jszip";

const sql = neon(process.env.DATABASE_URL);

const URLS = {
  tests: "https://cricsheet.org/downloads/tests_json.zip",
  odis: "https://cricsheet.org/downloads/odis_json.zip",
  t20s: "https://cricsheet.org/downloads/t20s_json.zip"
};

function legalBall(delivery) {
  return !delivery.extras?.wides;
}

function bowlerWicket(kind) {
  return ![
    "run out",
    "retired hurt",
    "retired out",
    "obstructing the field"
  ].includes(kind);
}

function ballsToOvers(balls) {
  const overs = Math.floor(balls / 6);
  const rem = balls % 6;
  return Number(`${overs}.${rem}`);
}

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function formatToMatchType(format) {
  if (format === "tests") return "test";
  if (format === "odis") return "odi";
  if (format === "t20s") return "t20";
  return format;
}

function normalizeFormat(format) {
  const f = String(format || "tests").toLowerCase();
  if (f === "test") return "tests";
  if (f === "odi") return "odis";
  if (f === "t20") return "t20s";
  return f;
}

function emptyBatting(playerName, playerId, team, inningsNumber) {
  return {
    innings_number: inningsNumber,
    player_name: playerName,
    cricsheet_player_id: playerId,
    team,
    runs: 0,
    balls: 0,
    fours: 0,
    sixes: 0,
    is_out: false,
    dismissal_type: null,
    dismissed_by_bowler: null,
    dismissed_by_fielder: null,
    raw_batting_json: []
  };
}

function emptyBowling(playerName, playerId, team, inningsNumber) {
  return {
    innings_number: inningsNumber,
    player_name: playerName,
    cricsheet_player_id: playerId,
    bowling_team: team,
    balls: 0,
    overs: 0,
    runs_conceded: 0,
    wickets: 0,
    raw_bowling_json: []
  };
}

function parseMatch(match, sourceMatchId) {
  const info = match.info || {};
  const registry = info.registry?.people || {};
  const teams = info.teams || [];
  const parsedRows = [];

  for (let i = 0; i < (match.innings || []).length; i++) {
    const innings = match.innings[i];
    const inningsNumber = i + 1;
    const battingTeam = innings.team;
    const bowlingTeam = teams.find(t => t !== battingTeam) || null;

    const batting = {};
    const bowling = {};

    for (const over of innings.overs || []) {
      for (const d of over.deliveries || []) {
        const batter = d.batter;
        const bowler = d.bowler;

        if (!batting[batter]) {
          batting[batter] = emptyBatting(
            batter,
            registry[batter],
            battingTeam,
            inningsNumber
          );
        }

        batting[batter].runs += d.runs?.batter || 0;

        if (legalBall(d)) {
          batting[batter].balls += 1;
        }

        if (d.runs?.batter === 4) batting[batter].fours += 1;
        if (d.runs?.batter === 6) batting[batter].sixes += 1;

        batting[batter].raw_batting_json.push(d);

        if (!bowling[bowler]) {
          bowling[bowler] = emptyBowling(
            bowler,
            registry[bowler],
            bowlingTeam,
            inningsNumber
          );
        }

        if (legalBall(d)) {
          bowling[bowler].balls += 1;
        }

        const extras = d.extras || {};
        const bowlerExtras = (extras.wides || 0) + (extras.noballs || 0);

        bowling[bowler].runs_conceded +=
          (d.runs?.batter || 0) + bowlerExtras;

        bowling[bowler].raw_bowling_json.push(d);

        for (const wicket of d.wickets || []) {
          const outPlayer = wicket.player_out;

          if (!batting[outPlayer]) {
            batting[outPlayer] = emptyBatting(
              outPlayer,
              registry[outPlayer],
              battingTeam,
              inningsNumber
            );
          }

          batting[outPlayer].is_out = true;
          batting[outPlayer].dismissal_type = wicket.kind;

          if (bowlerWicket(wicket.kind)) {
            batting[outPlayer].dismissed_by_bowler = bowler;
            bowling[bowler].wickets += 1;
          } else {
            batting[outPlayer].dismissed_by_bowler = null;
          }

          batting[outPlayer].dismissed_by_fielder =
            wicket.fielders?.map(f => f.name).join(", ") || null;
        }
      }
    }

    for (const bat of Object.values(batting)) {
      parsedRows.push({
        type: "batting",
        source_match_id: sourceMatchId,
        cricsheet_match_id: sourceMatchId,
        match_name: teams.join(" vs "),
        match_date: info.dates?.[0] || null,
        match_type: normalize(info.match_type),
        venue: info.venue || null,
        innings_number: bat.innings_number,
        cricsheet_player_id: bat.cricsheet_player_id,
        player_name: bat.player_name,
        team: bat.team,
        opponent: bowlingTeam,
        batting_team: battingTeam,
        bowling_team: bowlingTeam,
        runs: bat.runs,
        balls: bat.balls,
        fours: bat.fours,
        sixes: bat.sixes,
        strike_rate:
          bat.balls > 0
            ? Number(((bat.runs / bat.balls) * 100).toFixed(2))
            : null,
        dismissal_type: bat.dismissal_type,
        dismissed_by_bowler: bat.dismissed_by_bowler,
        dismissed_by_fielder: bat.dismissed_by_fielder,
        is_out: bat.is_out,
        raw_batting_json: bat.raw_batting_json,
        raw_scorecard_json: match
      });
    }

    for (const bowl of Object.values(bowling)) {
      const overs = ballsToOvers(bowl.balls);

      parsedRows.push({
        type: "bowling",
        source_match_id: sourceMatchId,
        cricsheet_match_id: sourceMatchId,
        match_name: teams.join(" vs "),
        match_date: info.dates?.[0] || null,
        match_type: normalize(info.match_type),
        venue: info.venue || null,
        innings_number: bowl.innings_number,
        cricsheet_player_id: bowl.cricsheet_player_id,
        player_name: bowl.player_name,
        team: bowl.bowling_team,
        opponent: battingTeam,
        batting_team: battingTeam,
        bowling_team: bowlingTeam,
        overs,
        balls: bowl.balls,
        runs_conceded: bowl.runs_conceded,
        wickets: bowl.wickets,
        economy:
          bowl.balls > 0
            ? Number((bowl.runs_conceded / (bowl.balls / 6)).toFixed(2))
            : null,
        raw_bowling_json: bowl.raw_bowling_json,
        raw_scorecard_json: match
      });
    }
  }

  return parsedRows;
}

async function loadMappedPlayers({ player, onlyMissing, matchType }) {
  let mappedPlayers = await sql`
    SELECT
      m.cricapi_player_id,
      m.cricsheet_player_id,
      m.player_name,
      m.country,
      m.mapping_status
    FROM cricsheet_player_mapping m
    WHERE m.cricsheet_player_id IS NOT NULL
      AND m.mapping_status = 'mapped'
      AND (
        ${player || null}::text IS NULL
        OR LOWER(m.player_name) = LOWER(${player || ""})
      )
    ORDER BY m.country, m.player_name
  `;

  if (onlyMissing) {
    const playersWithHistory = await sql`
      SELECT DISTINCT cricsheet_player_id
      FROM cricapi_player_match_history
      WHERE cricsheet_player_id IS NOT NULL
        AND match_type = ${matchType}
        AND data_source = 'cricsheet'
    `;

    const done = new Set(playersWithHistory.map(r => r.cricsheet_player_id));
    mappedPlayers = mappedPlayers.filter(p => !done.has(p.cricsheet_player_id));
  }

  return mappedPlayers;
}

async function processFormat({
  format,
  player,
  maxFiles,
  limitPerPlayer,
  onlyMissing
}) {
  const matchType = formatToMatchType(format);

  const mappedPlayers = await loadMappedPlayers({
    player,
    onlyMissing,
    matchType
  });

  const selectedByCricsheetId = new Map(
    mappedPlayers.map(p => [p.cricsheet_player_id, p])
  );

  const counts = new Map(
    mappedPlayers.map(p => [p.cricsheet_player_id, 0])
  );

  if (mappedPlayers.length === 0) {
    return {
      format,
      matchType,
      mapped_players_processed: 0,
      files_scanned: 0,
      matched_matches: 0,
      inserted_or_updated_rows: 0,
      message: "No mapped players found for this filter"
    };
  }

  const response = await fetch(URLS[format]);

  if (!response.ok) {
    throw new Error(`Failed to download Cricsheet zip for ${format}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const zip = await JSZip.loadAsync(arrayBuffer);

  const allJsonFiles = Object.values(zip.files)
    .filter(file => !file.dir && file.name.endsWith(".json"))
    .map(file => file.name);

  const datedFiles = [];

  for (const fileName of allJsonFiles) {
    const text = await zip.file(fileName).async("text");
    const match = JSON.parse(text);

    datedFiles.push({
      fileName,
      matchDate: match.info?.dates?.[0] || "1900-01-01"
    });
  }

  const jsonFiles = datedFiles
    .sort((a, b) => new Date(b.matchDate) - new Date(a.matchDate))
    .slice(0, maxFiles)
    .map(x => x.fileName);

  const insertedRows = [];
  const matchedMatches = [];

  for (const fileName of jsonFiles) {
    const text = await zip.file(fileName).async("text");
    const match = JSON.parse(text);

    const parsedRows = parseMatch(match, fileName.replace(".json", ""));

    const relevantRows = parsedRows.filter(row =>
      selectedByCricsheetId.has(row.cricsheet_player_id)
    );

    if (relevantRows.length === 0) continue;

    matchedMatches.push({
      fileName,
      match_name: parsedRows[0]?.match_name,
      match_date: parsedRows[0]?.match_date,
      match_type: matchType
    });

    const relevantPlayerIdsInThisMatch = new Set(
      relevantRows.map(r => r.cricsheet_player_id)
    );

    for (const row of relevantRows) {
      const selectedPlayer = selectedByCricsheetId.get(row.cricsheet_player_id);
      const currentCount = counts.get(row.cricsheet_player_id) || 0;

      if (currentCount >= limitPerPlayer) {
        continue;
      }

      const uniqueRowKey =
        row.cricsheet_match_id + "*" + row.innings_number + "*" + row.type;

      await sql`
        INSERT INTO cricapi_player_match_history (
          cricapi_match_id,
          source_match_id,
          data_source,
          cricapi_player_id,
          cricsheet_player_id,
          player_name,
          country,
          match_name,
          match_date,
          match_type,
          team,
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
          overs,
          runs_conceded,
          wickets,
          economy,
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
          ${uniqueRowKey},
          ${row.source_match_id},
          ${"cricsheet"},
          ${selectedPlayer.cricapi_player_id},
          ${row.cricsheet_player_id},
          ${selectedPlayer.player_name},
          ${selectedPlayer.country},
          ${row.match_name},
          ${row.match_date},
          ${matchType},
          ${row.team},
          ${row.opponent},
          ${row.venue},
          ${row.innings_number},
          ${row.batting_team},
          ${row.bowling_team},
          ${row.runs || 0},
          ${row.balls || 0},
          ${row.fours || 0},
          ${row.sixes || 0},
          ${row.strike_rate || null},
          ${row.overs || 0},
          ${row.runs_conceded || 0},
          ${row.wickets || 0},
          ${row.economy || null},
          ${row.dismissal_type || null},
          ${row.dismissed_by_bowler || null},
          ${row.dismissed_by_fielder || null},
          ${row.is_out || false},
          ${JSON.stringify(row.raw_batting_json || null)},
          ${JSON.stringify(row.raw_bowling_json || null)},
          ${JSON.stringify(row.raw_scorecard_json || null)},
          NOW()
        )
        ON CONFLICT (cricapi_match_id, cricapi_player_id)
        DO UPDATE SET
          cricsheet_player_id = EXCLUDED.cricsheet_player_id,
          player_name = EXCLUDED.player_name,
          country = EXCLUDED.country,
          match_name = EXCLUDED.match_name,
          match_date = EXCLUDED.match_date,
          match_type = EXCLUDED.match_type,
          team = EXCLUDED.team,
          opponent = EXCLUDED.opponent,
          venue = EXCLUDED.venue,
          innings_number = EXCLUDED.innings_number,
          batting_team = EXCLUDED.batting_team,
          bowling_team = EXCLUDED.bowling_team,
          runs = EXCLUDED.runs,
          balls = EXCLUDED.balls,
          fours = EXCLUDED.fours,
          sixes = EXCLUDED.sixes,
          strike_rate = EXCLUDED.strike_rate,
          overs = EXCLUDED.overs,
          runs_conceded = EXCLUDED.runs_conceded,
          wickets = EXCLUDED.wickets,
          economy = EXCLUDED.economy,
          dismissal_type = EXCLUDED.dismissal_type,
          dismissed_by_bowler = EXCLUDED.dismissed_by_bowler,
          dismissed_by_fielder = EXCLUDED.dismissed_by_fielder,
          is_out = EXCLUDED.is_out,
          raw_batting_json = EXCLUDED.raw_batting_json,
          raw_bowling_json = EXCLUDED.raw_bowling_json,
          raw_scorecard_json = EXCLUDED.raw_scorecard_json,
          updated_at = NOW()
      `;

      insertedRows.push({
        player_name: selectedPlayer.player_name,
        format,
        matchType,
        fileName,
        uniqueRowKey,
        innings_number: row.innings_number,
        type: row.type,
        runs: row.runs || 0,
        wickets: row.wickets || 0
      });
    }

    for (const playerId of relevantPlayerIdsInThisMatch) {
      const currentCount = counts.get(playerId) || 0;
      if (currentCount < limitPerPlayer) {
        counts.set(playerId, currentCount + 1);
      }
    }

    const allDone = Array.from(counts.values()).every(
      count => count >= limitPerPlayer
    );

    if (allDone) break;
  }

  return {
    format,
    matchType,
    player_filter: player || null,
    onlyMissing,
    maxFiles,
    limitPerPlayer,
    mapped_players_processed: mappedPlayers.length,
    files_scanned: jsonFiles.length,
    matched_matches: matchedMatches.length,
    inserted_or_updated_rows: insertedRows.length,
    counts_by_cricsheet_player_id: Object.fromEntries(counts),
    matchedMatches,
    insertedRows
  };
}

export default async function handler(req, res) {
  try {
    const rawFormat = String(req.query.format || "tests").toLowerCase();
    const player = req.query.player ? String(req.query.player).trim() : null;
    const maxFiles = Number(req.query.maxFiles || 5000);
    const limitPerPlayer = Number(req.query.limitPerPlayer || 5);
    const onlyMissing = String(req.query.onlyMissing || "false") === "true";

    const formats =
      rawFormat === "all"
        ? ["tests", "odis", "t20s"]
        : [normalizeFormat(rawFormat)];

    for (const f of formats) {
      if (!URLS[f]) {
        return res.status(400).json({
          success: false,
          error:
            "Use ?format=tests, ?format=odis, ?format=t20s, ?format=test, ?format=odi, ?format=t20, or ?format=all"
        });
      }
    }

    const mappingSummary = await sql`
      SELECT
        COUNT(*)::int AS total_players,
        COUNT(*) FILTER (
          WHERE cricsheet_player_id IS NOT NULL
            AND mapping_status = 'mapped'
        )::int AS mapped_players,
        COUNT(*) FILTER (
          WHERE cricsheet_player_id IS NULL
             OR mapping_status IS DISTINCT FROM 'mapped'
        )::int AS unmapped_players
      FROM cricsheet_player_mapping
    `;

    const results = [];

    for (const format of formats) {
      const result = await processFormat({
        format,
        player,
        maxFiles,
        limitPerPlayer,
        onlyMissing
      });

      results.push(result);
    }

    return res.status(200).json({
      success: true,
      requested_format: rawFormat,
      player_filter: player,
      maxFiles,
      limitPerPlayer,
      onlyMissing,
      total_players_in_mapping_table: mappingSummary[0]?.total_players || 0,
      mapped_players_available: mappingSummary[0]?.mapped_players || 0,
      unmapped_players_skipped: mappingSummary[0]?.unmapped_players || 0,
      results
    });
  } catch (error) {
    console.error("backfill-player-history-from-cricsheet error:", error);

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
