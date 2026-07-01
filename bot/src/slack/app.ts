import { App } from '@slack/bolt';
import { registerSupportCommand } from './commands/support';
import { getTicket, resolveTicket, createTicket, reopenTicket, updateLastActivity } from '../db/tickets';
import { isStaffMember } from '../db/support';
import { logAudit } from '../db/audit';
import { config } from '../config';

export function createSlackApp(): App {
  if (!config.slack.botToken || !config.slack.appToken) {
    throw new Error(
      'Missing Slack credentials. Please set SLACK_BOT_TOKEN, SLACK_APP_TOKEN, and SLACK_SIGNING_SECRET in your .env file.',
    );
  }

  const app = new App({
    token: config.slack.botToken,
    appToken: config.slack.appToken,
    signingSecret: config.slack.signingSecret,
    socketMode: true,
  });

  registerMessageEvents(app);
  registerSupportCommand(app);

  app.action('resolve_ticket', async ({ action, body, client, respond }) => {
    const ticketId = (action as any).value as string;
    const clickerId = (body as any).user.id;

    const ticket = getTicket(ticketId);
    if (!ticket || ticket.status === 'resolved') return;

    const isOriginalPoster = ticket.user_id === clickerId;
    const isSupport = isStaffMember(clickerId);

    if (!isOriginalPoster && !isSupport) {
      await respond({
        text: 'Only the original poster or a support team member can resolve this ticket.',
        response_type: 'ephemeral',
      });
      return;
    }

    resolveTicket(ticketId, clickerId);
    logAudit(clickerId, clickerId, 'resolve', `Resolved ticket #${ticket.ticket_number} from Slack`);

    await client.chat.postMessage({
      channel: ticket.channel_id,
      thread_ts: ticket.thread_ts,
      text: ':white_check_mark: This has been marked as resolved. If your question hasn\'t been answered please reply back to reopen this ticket.',
    });
  });

  return app;
}

function registerMessageEvents(app: App): void {
  app.message(async ({ message, say, client }) => {
    if (message.subtype || message.bot_id) return;
    const ch = (message as any).channel || (message as any).channel_id;
    if (ch !== config.slack.channelId) return;

    if (!(message as any).thread_ts) {
      createTicket(message.ts!, ch, (message as any).user);
      updateLastActivity(message.ts!);
      await say({
        thread_ts: message.ts,
        text: `Hi welcome to heist! Please check out the <${config.faq.link}|FAQ> and a member from our support team will be with you soon!`,
        blocks: [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `Hi welcome to heist! Please check out the <${config.faq.link}|FAQ> and a member from our support team will be with you soon!`,
            },
          },
          {
            type: 'actions',
            elements: [
              {
                type: 'button',
                text: { type: 'plain_text', text: 'Resolve Ticket', emoji: true },
                style: 'primary',
                action_id: 'resolve_ticket',
                value: message.ts,
              },
            ],
          },
        ],
      });
    } else {
      const ticket = getTicket((message as any).thread_ts);
      if (ticket && ticket.status === 'resolved') {
        reopenTicket(ticket.thread_ts);
        updateLastActivity(ticket.thread_ts);
        logAudit((message as any).user, (message as any).user, 'reopen', `Reopened ticket #${ticket.ticket_number} via thread reply`);
        await client.chat.postMessage({
          channel: ticket.channel_id,
          thread_ts: ticket.thread_ts,
          text: ':arrows_counterclockwise: This ticket has been reopened.',
        });
      }
    }
  });
}
