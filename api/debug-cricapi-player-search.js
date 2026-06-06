export default async function handler(req, res) {
  try {
    const { search = "" } = req.query;

    if (!search) {
      return res.status(400).json({
        success: false,
        error: "Provide ?search=playerName"
      });
    }

    const url =
      `https://api.cricapi.com/v1/players?apikey=${process.env.CRICAPI_KEY}` +
      `&search=${encodeURIComponent(search)}`;

    const response = await fetch(url);
    const data = await response.json();

    return res.status(200).json({
      success: true,
      search,
      raw: data,
      players: data.data || []
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
