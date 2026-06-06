import JSZip from "jszip";

export default async function handler(req, res) {
  try {
    const {
      format = "odis",
      name = "",
      playerId = "",
      team = "",
      maxFiles = 5000
    } = req.query;

    if (!name && !playerId && !team) {
      return res.status(400).json({
        success: false,
        error: "Provide name, playerId, or team"
      });
    }

    const URLS = {
      tests: "https://cricsheet.org/downloads/tests_json.zip",
      odis: "https://cricsheet.org/downloads/odis_json.zip",
      t20s: "https://cricsheet.org/downloads/t20s_json.zip"
    };

    if (!URLS[format]) {
      return res.status(400).json({
        success: false,
        error: "Invalid format. Use tests, odis, or t20s."
      });
    }

    const response = await fetch(URLS[format]);
    const buffer = await response.arrayBuffer();
    const zip = await JSZip.loadAsync(buffer);

    const files = Object.values(zip.files)
      .filter(file => !file.dir && file.name.endsWith(".json"));

    const nameTerm = String(name).toLowerCase();
    const teamTerm = String(team).toLowerCase();

    const matches = [];
    let scannedFiles = 0;

    for (const file of files) {
      if (scannedFiles >= Number(maxFiles)) break;
      scannedFiles += 1;

      try {
        const text = await file.async("text");
        const match = JSON.parse(text);

        const teams = match.info?.teams || [];
        const registry = match.info?.registry?.people || {};

        const teamMatch =
          team &&
          teams.some(t => String(t).toLowerCase().includes(teamTerm));

        if (teamMatch) {
          matches.push({
            file: file.name,
            match_date: match.info?.dates?.[0] || null,
            teams,
            registry_people: registry
          });

          continue;
        }

        for (const [playerName, playerIdFromRegistry] of Object.entries(registry)) {
          const nameMatch =
            name &&
            playerName.toLowerCase().includes(nameTerm);

          const idMatch =
            playerId &&
            playerId === playerIdFromRegistry;

          if (nameMatch || idMatch) {
            matches.push({
              file: file.name,
              player_name: playerName,
              cricsheet_player_id: playerIdFromRegistry,
              match_date: match.info?.dates?.[0] || null,
              teams
            });
          }
        }
      } catch (err) {
        continue;
      }
    }

    return res.status(200).json({
      success: true,
      format,
      search_name: name,
      search_player_id: playerId,
      search_team: team,
      files_scanned: scannedFiles,
      total_matches_found: matches.length,
      matches: matches.slice(0, 50)
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.message
    });
  }
}
