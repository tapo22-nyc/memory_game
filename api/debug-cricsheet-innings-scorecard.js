import JSZip from "jszip";

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
    dismissed_by_fielder: null
  };
}

function emptyBowling(playerName, playerId, team, inningsNumber) {
  return {
    innings_number: inningsNumber,
    player_name: playerName,
    cricsheet_player_id: playerId,
    bowling_team: team,
    balls: 0,
    overs: "0.0",
    runs_conceded: 0,
    wickets: 0
  };
}

function ballsToOvers(balls) {
  const overs = Math.floor(balls / 6);
  const rem = balls % 6;
  return `${overs}.${rem}`;
}

export default async function handler(req, res) {
  try {
    const format = String(req.query.format || "tests").toLowerCase();
    const fileName = req.query.file || null;

    if (!URLS[format]) {
      return res.status(400).json({
        success: false,
        error: "Use ?format=tests, ?format=odis, or ?format=t20s"
      });
    }

    const response = await fetch(URLS[format]);
    const arrayBuffer = await response.arrayBuffer();
    const zip = await JSZip.loadAsync(arrayBuffer);

    const jsonFiles = Object.values(zip.files)
      .filter(file => !file.dir && file.name.endsWith(".json"))
      .map(file => file.name)
      .sort();

    const selectedFile = fileName || jsonFiles[jsonFiles.length - 1];

    const zipFile = zip.file(selectedFile);

    if (!zipFile) {
      return res.status(404).json({
        success: false,
        error: "File not found",
        selectedFile,
        sample_files: jsonFiles.slice(-10)
      });
    }

    const text = await zipFile.async("text");
    const match = JSON.parse(text);

    const info = match.info || {};
    const registry = info.registry?.people || {};
    const teams = info.teams || [];

    const inningsScorecards = [];

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
          const bowlerExtras =
            (extras.wides || 0) +
            (extras.noballs || 0);

          bowling[bowler].runs_conceded +=
            (d.runs?.batter || 0) + bowlerExtras;

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

      const bowlingRows = Object.values(bowling).map(row => ({
        ...row,
        overs: ballsToOvers(row.balls)
      }));

      inningsScorecards.push({
        innings_number: inningsNumber,
        batting_team: battingTeam,
        bowling_team: bowlingTeam,
        batting: Object.values(batting),
        bowling: bowlingRows
      });
    }

    return res.status(200).json({
      success: true,
      format,
      selected_file: selectedFile,
      match: {
        dates: info.dates,
        venue: info.venue,
        teams: info.teams,
        match_type: info.match_type,
        event: info.event,
        outcome: info.outcome
      },
      innings_count: inningsScorecards.length,
      innings_scorecards: inningsScorecards
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
