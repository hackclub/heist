import dotenv from 'dotenv';
dotenv.config();

export const config = {
  slack: {
    botToken: process.env.SLACK_BOT_TOKEN || '',
    appToken: process.env.SLACK_APP_TOKEN || '',
    signingSecret: process.env.SLACK_SIGNING_SECRET || '',
    ownerUserId: process.env.SLACK_OWNER_USER_ID || '',
    adminUserIds: (process.env.SLACK_ADMIN_USER_IDS || '').split(',').map((s) => s.trim()).filter(Boolean),
    channelId: process.env.SLACK_CHANNEL_ID || '',
  },
  faq: {
    link: process.env.FAQ_LINK || 'https://heist.faq/',
  },
  web: {
    port: parseInt(process.env.WEB_PORT || '3000', 10),
    sessionSecret: process.env.SESSION_SECRET || 'change-me-in-production',
  },
  oauth: {
    clientId: process.env.HC_CLIENT_ID || '',
    clientSecret: process.env.HC_CLIENT_SECRET || '',
    redirectUri: process.env.HC_REDIRECT_URI || '',
  },
};
