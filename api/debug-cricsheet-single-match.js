import JSZip from "jszip";

const URLS = {
  tests: "https://cricsheet.org/downloads/tests_json.zip",
  odis: "https://cricsheet.org/downloads/odis_json.zip",
  t20s: "https://cricsheet.org/downloads/t20s_json.zip"
};

export default async function handler(req, res) {
  try {
    const format = String(req.query.format || "tests").toLowerCase();
    const fileName = req.query.file || null;

    const url = URLS[format];

    if (!url) {
      return res.status(400).json({
        success: false,
        error: "Use ?format=tests, ?format=odis, or ?format=t20s"
      });
    }

    const response = await fetch(url);
    const arrayBuffer = await response.arrayBuffer();
    const zip = await JSZip.loadAsync(arrayBuffer);

    const jsonFiles = Object.values(zip.files)
      .filter(file => !file.dir && file.name.endsWith(".json"))
      .map(file => file.name)
      .sort();

    const selectedFile = fileName || jsonFiles[jsonFiles.length - 1];

    const file = zip.file(selectedFile);

    if (!file) {
      return res.status(404).json({
        success: false,
        error: "File not found in ZIP",
        selectedFile,
        sample_files: jsonFiles.slice(-10)
      });
    }

    const text = await file.async("text");
    const match = JSON.parse(text);

    const info = match.info || {};
    const innings = match.innings || [];

    const firstInnings = innings[0] || {};
    const firstOvers = firstInnings.overs || [];
    const firstOver = firstOvers[0] || {};
    const firstDelivery = firstOver.deliveries?.[0] || null;

    return res.status(200).json({
      success: true,
      format,
      total_json_files: jsonFiles.length,
      selected_file: selectedFile,

      top_level_keys: Object.keys(match),
      info_keys: Object.keys(info),

      match_summary: {
        dates: info.dates,
        venue: info.venue,
        teams: info.teams,
        event: info.event,
        match_type: info.match_type,
        gender: info.gender,
        outcome: info.outcome
      },

      registry_sample: info.registry?.people || null,

      innings_count: innings.length,
      first_innings_keys: Object.keys(firstInnings),
      first_innings_team: firstInnings.team,
      first_over_keys: Object.keys(firstOver),
      first_delivery_sample: firstDelivery,

      raw_first_innings_sample: firstInnings
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
