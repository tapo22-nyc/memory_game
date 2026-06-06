import JSZip from "jszip";

export default async function handler(req, res) {
  try {
    const {
      format = "odis",
      name = "",
      playerId = "",
      maxFiles = 1000
    } = req.query;

    if (!name && !playerId) {
      return res.status(400).json({
        success: false,
        error: "Either name or playerId parameter is required"
      });
    }

    let zipUrl = "";

    if (format === "tests") {
      zipUrl = "https://cricsheet.org/downloads/tests_json.zip";
    } else if (format === "odis") {
      zipUrl = "https://cricsheet.org/downloads/odis_json.zip";
    } else if (format === "t20s") {
      zipUrl = "https://cricsheet.org/downloads/t20s_json.zip";
    } else {
      return res.status(400).json({
        success: false,
        error: "invalid format"
      });
    }

    const response = await fetch(zipUrl);
    const buffer = await response.arrayBuffer();

    const zip = await JSZip.loadAsync(buffer);

    const files = Object.values(zip.files)
      .filter(
        (file) =>
          !file.dir &&
          file.name.endsWith(".json")
      )
      .slice(0, Number(maxFiles));

    const searchTerm = name.toLowerCase();

    const matches = [];

    for (const file of files) {
      try {
        const text = await file.async("text");
        const match = JSON.parse(text);

        const registry =
          match.info?.registry?.people || {};

        for (const [playerName, playerIdFromRegistry] of Object.entries(registry)) {

          const nameMatch =
            name &&
            playerName.toLowerCase().includes(searchTerm);

          const idMatch =
            playerId &&
            playerId === playerIdFromRegistry;

          if (nameMatch || idMatch) {
            matches.push({
              file: file.name,
              player_name: playerName,
              cricsheet_player_id: playerIdFromRegistry,
              match_date:
                match.info?.dates?.[0] || null,
              teams:
                match.info?.teams || []
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
      total_matches_found: matches.length,
      matches: matches.slice(0, 100)
    });

  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.message
    });
  }
}
