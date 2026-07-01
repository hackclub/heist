import { config } from './config';
import { createSlackApp } from './slack/app';
import { createWebServer } from './web/server';
import { seedAdminsFromEnv } from './db/support';
import { getStaleClaimed } from './db/tickets';

async function main(): Promise<void> {
  console.log('Starting Heist Support Bot...');

  const slackApp = createSlackApp();
  await slackApp.start();
  console.log('Slack bot is running (Socket Mode)');

  seedAdminsFromEnv();
  console.log('Admins seeded from env');

  const webApp = createWebServer(slackApp);
  webApp.listen(config.web.port, () => {
    console.log(`Web server running on port ${config.web.port}`);
  });

  setInterval(async () => {
    try {
      const stale = getStaleClaimed(3);
      for (const t of stale) {
        if (t.claimed_by) {
          await slackApp.client.chat.postMessage({
            channel: t.claimed_by,
            text: `:warning: Heads up! Ticket #${t.ticket_number} has been assigned to you and hasn't had activity in 3+ days. Please catch up: <#${t.channel_id}|thread>`,
          });
        }
      }
      if (stale.length > 0) console.log(`[reminder] Sent ${stale.length} stale ticket DMs`);
    } catch (e) { /* */ }
  }, 86400000); // once per day

  process.on('SIGINT', async () => {
    console.log('\nShutting down...');
    await slackApp.stop();
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.log('\nShutting down...');
    await slackApp.stop();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error('Failed to start:', err);
  process.exit(1);
});
