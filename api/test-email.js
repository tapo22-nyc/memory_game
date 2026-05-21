import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

export default async function handler(req, res) {
  try {
    const data = await resend.emails.send({
      from: 'MT Games <login@playmtgames.com>',
      to: 'YOUR_PERSONAL_EMAIL@gmail.com',
      subject: 'MT Games Test Email',
      html: `
        <h1>MT Games Email Working 🚀</h1>
        <p>Your Resend integration is successful.</p>
      `
    });

    return res.status(200).json({
      success: true,
      data
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
