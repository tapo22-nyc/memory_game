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

    return res.status(200).json({
      success: true,
      format,
      url,
      status: response.status,
      content_type: response.headers.get("content-type"),
      content_length: response.headers.get("content-length")
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
