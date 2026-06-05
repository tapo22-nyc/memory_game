import JSZip from "jszip";

export default async function handler(req, res) {
  try {
    const format = String(req.query.format || "tests").toLowerCase();

    const urls = {
      tests: "https://cricsheet.org/downloads/tests_json.zip",
      odis: "https://cricsheet.org/downloads/odis_json.zip",
      t20s: "https://cricsheet.org/downloads/t20s_json.zip"
    };

    const url = urls[format];

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
      .map(file => file.name);

    return res.status(200).json({
      success: true,
      format,
      total_json_files: jsonFiles.length,
      first_5_files: jsonFiles.slice(0, 5),
      last_5_files: jsonFiles.slice(-5)
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
