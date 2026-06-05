export default async function handler(req, res) {
  try {
    const matchId = req.query.id;

    if (!matchId) {
      return res.status(400).json({
        success: false,
        error: "Please pass match id like ?id=MATCH_ID"
      });
    }

    const url =
      `https://api.cricapi.com/v1/match_scorecard?apikey=${process.env.CRICAPI_KEY}` +
      `&id=${encodeURIComponent(matchId)}`;

    const response = await fetch(url);
    const data = await response.json();

    return res.status(200).json({
      success: true,
      top_level_keys: Object.keys(data || {}),
      data_keys: Object.keys(data.data || {}),
      full_response: data
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
