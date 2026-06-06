import JSZip from "jszip";

const URLS = {
  tests: "https://cricsheet.org/downloads/tests_json.zip",
  odis: "https://cricsheet.org/downloads/odis_json.zip",
  t20s: "https://cricsheet.org/downloads/t20s_json.zip"
};

function legalBall(delivery) {
  return !(delivery.extras?.wides);
}

function bowlerWicket(kind) {
  return ![
    "run out",
    "retired hurt",
    "retired out",
    "obstructing the field"
  ].includes(kind);
}

export default async function handler(req, res) {
  try {
    const format = String(req.query.format || "tests").toLowerCase();
    const fileName = req.query.file || null;

    const response = await fetch(URLS[format]);
    const arrayBuffer = await response.arrayBuffer();
    const zip = await JSZip.loadAsync(arrayBuffer);

    const jsonFiles = Object.values(zip.files)
      .filter(file => !file.dir && file.name.endsWith(".json"))
      .map(file => file.name)
      .sort();

    const selectedFile = fileName || jsonFiles[jsonFiles.length - 1];
    const text = await zip.file(selectedFile).async("text");
    const match = JSON.parse(text);

    const info = match.info;
    const registry = info.registry?.people || {};

    const batting = {};
    const bowling = {};

    for (const innings of match.innings || []) {
      const battingTeam = innings.team;

      for (const over of innings.overs || []) {
        for (const d of over.deliveries || []) {
          const batter = d.batter;
          const bowler = d.bowler;

          if (!batting[batter]) {
            batting[batter] = {
              player_name: batter,
              cricsheet_player_id: registry[batter],
              team: battingTeam,
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

          batting[batter].runs += d.runs?.batter || 0;

          if (legalBall(d)) {
            batting[batter].balls += 1;
          }

          if (d.runs?.batter === 4) batting[batter].fours += 1;
          if (d.runs?.batter === 6) batting[batter].sixes += 1;

          if (!bowling[bowler]) {
            bowling[bowler] = {
              player_name: bowler,
              cricsheet_player_id: registry[bowler],
              balls: 0,
              runs_conceded: 0,
              wickets: 0
            };
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
              batting[outPlayer] = {
                player_name: outPlayer,
                cricsheet_player_id: registry[outPlayer],
                team: battingTeam,
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

            batting[outPlayer].is_out = true;
            batting[outPlayer].dismissal_type = wicket.kind;
            batting[outPlayer].dismissed_by_bowler = bowler;
            batting[outPlayer].dismissed_by_fielder =
              wicket.fielders?.[0]?.name || null;

            if (bowlerWicket(wicket.kind)) {
              bowling[bowler].wickets += 1;
            }
          }
        }
      }
    }

    return res.status(200).json({
      success: true,
      format,
      selected_file: selectedFile,
      match: {
        dates: info.dates,
        venue: info.venue,
        teams: info.teams,
        match_type: info.match_type
      },
      batting: Object.values(batting),
      bowling: Object.values(bowling)
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
