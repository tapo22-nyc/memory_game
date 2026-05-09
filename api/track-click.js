const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const {
      user_id,
      user_name,
      event_name,
      button_name,
      page_name,
      page_url,
      fantasy_match_id,
      ipl_match_id,
      event_metadata
    } = req.body || {};

    if (!button_name) {
      return res.status(400).json({ error: 'button_name is required' });
    }

    await sql`
      INSERT INTO user_clickstream_events
      (
        user_id,
        user_name,
        event_name,
        button_name,
        page_name,
        page_url,
        fantasy_match_id,
        ipl_match_id,
        event_metadata
      )
      VALUES
      (
        ${user_id ? Number(user_id) : null},
        ${user_name || null},
        ${event_name || 'button_click'},
        ${button_name},
        ${page_name || null},
        ${page_url || null},
        ${fantasy_match_id ? Number(fantasy_match_id) : null},
        ${ipl_match_id ? Number(ipl_match_id) : null},
        ${event_metadata || {}}
      )
    `;

    return res.status(200).json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
