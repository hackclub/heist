import { App } from '@slack/bolt';
import { config } from '../../config';
import { addSupportMember, removeSupportMember, addAdmin, removeAdmin, isAdminMember } from '../../db/support';
import { logAudit } from '../../db/audit';

function extractUserId(text: string): string | null {
  const mentionMatch = text.match(/<@([A-Z0-9]+)(?:\|[^>]+)?>/);
  if (mentionMatch) return mentionMatch[1];
  const idMatch = text.match(/\b(U[A-Z0-9]{8,})\b/);
  if (idMatch) return idMatch[1];
  return null;
}

export function registerSupportCommand(app: App): void {
  app.command('/support', async ({ command, ack, respond }) => {
    try {
      await ack();

      const commandUserId = command.user_id;
      const isOwner = commandUserId === config.slack.ownerUserId;
      const isAdmin = !isOwner && isAdminMember(commandUserId);

      if (!isOwner && !isAdmin) {
        await respond({
          text: 'You do not have permission to use this command.',
          response_type: 'ephemeral',
        });
        return;
      }

      const text = command.text.trim();
      const parts = text.split(/\s+/);
      const action = parts[0]?.toLowerCase() || '';
      const targetUserId = extractUserId(text);

      if (!targetUserId) {
        await respond({
          text: 'Could not find a user. Use @mention or raw user ID.\n```\n/support admin @user\n/support unadmin @user\n/support enable @user\n/support disable @user\n```',
          response_type: 'ephemeral',
        });
        return;
      }

      if (action === 'admin') {
        if (!isOwner) {
          await respond({ text: 'Only the owner can promote admins.', response_type: 'ephemeral' });
          return;
        }
        const added = addAdmin(targetUserId, commandUserId);
        logAudit(commandUserId, commandUserId, 'admin', `Promoted ${targetUserId} to admin`);
        await respond({
          text: added
            ? `<@${targetUserId}> is now an admin.`
            : `<@${targetUserId}> is already an admin.`,
          response_type: 'ephemeral',
        });
        return;
      }

      if (action === 'unadmin') {
        if (!isOwner) {
          await respond({ text: 'Only the owner can demote admins.', response_type: 'ephemeral' });
          return;
        }
        if (targetUserId === config.slack.ownerUserId) {
          await respond({ text: 'The owner cannot be demoted.', response_type: 'ephemeral' });
          return;
        }
        const removed = removeAdmin(targetUserId);
        logAudit(commandUserId, commandUserId, 'unadmin', `Demoted ${targetUserId} from admin`);
        await respond({
          text: removed
            ? `<@${targetUserId}> is no longer an admin.`
            : `<@${targetUserId}> is not an admin.`,
          response_type: 'ephemeral',
        });
        return;
      }

      if (action === 'enable') {
        const added = addSupportMember(targetUserId, commandUserId);
        logAudit(commandUserId, commandUserId, 'enable', `Added ${targetUserId} to support team`);
        await respond({
          text: added
            ? `<@${targetUserId}> added to support team.`
            : `<@${targetUserId}> is already on the support team.`,
          response_type: 'ephemeral',
        });
        return;
      }

      if (action === 'disable') {
        if (targetUserId === config.slack.ownerUserId) {
          await respond({ text: 'The owner cannot be disabled.', response_type: 'ephemeral' });
          return;
        }
        if (isAdmin && isAdminMember(targetUserId)) {
          await respond({ text: 'You cannot disable another admin.', response_type: 'ephemeral' });
          return;
        }
        const removed = removeSupportMember(targetUserId);
        logAudit(commandUserId, commandUserId, 'disable', `Removed ${targetUserId} from support team`);
        await respond({
          text: removed
            ? `<@${targetUserId}> removed from support team.`
            : `<@${targetUserId}> is not on the support team.`,
          response_type: 'ephemeral',
        });
        return;
      }

      await respond({
        text: 'Usage:\n```\n/support admin @user     (owner only)\n/support unadmin @user  (owner only)\n/support enable @user\n/support disable @user\n```',
        response_type: 'ephemeral',
      });
    } catch (err) {
      console.error('[/support] Error:', err);
    }
  });
}
