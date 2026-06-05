export default async function handler(req, res) {
  try {
    const url = "https://cricsheet.org/register/people.csv";

    const response = await fetch(url);
    const text = await response.text();

    if (!response.ok) {
      throw new Error(`Cricsheet people.csv failed: ${response.status}`);
    }

    const lines = text.split("\n").slice(0, 20);

    return res.status(200).json({
      success: true,
      total_lines: text.split("\n").length,
      sample_lines: lines
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
