const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { user_name, user_question, user_email, message_type } = req.body || {};

    if (!user_name || !user_question || !user_email || !message_type) {
      return res.status(400).json({ error: 'All fields are required.' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(user_email)) {
      return res.status(400).json({ error: 'Invalid email address.' });
    }

    await sql`
      INSERT INTO contact_us_submissions
        (user_name, user_question, user_email, message_type)
      VALUES
        (${user_name.trim()}, ${user_question.trim()}, ${user_email.trim()}, ${message_type.trim()})
    `;

    return res.status(200).json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
