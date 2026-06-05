export default async function handler(req, res) {
  try {
    const url =
      `https://api.cricapi.com/v1/currentMatches?apikey=${process.env.CRICAPI_KEY}` +
      `&offset=0`;

    const response = await fetch(url);
    const data = await response.json();

    return res.status(200).json({
      success: true,
      top_level_keys: Object.keys(data || {}),
      total: data.data?.length || 0,
      matches: data.data || []
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
