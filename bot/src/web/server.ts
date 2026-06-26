import express from 'express';
import path from 'path';
import session from 'express-session';
import { App } from '@slack/bolt';
import { getTicketStats, getAllTickets, getTicket, getTicketByNumber, resolveTicket, reopenTicket, getDailyStats, getTopCreators, getTopResolvers, getAvgResponseTime, getTicketCountByWeekday, getOldestOpen, updateLastActivity, assignTicket, getStaleClaimed, getMyTickets } from '../db/tickets';
import { getAllSupportMembers, isSupportMember, isStaffMember } from '../db/support';
import { logAudit, getAuditLogs } from '../db/audit';
import { addNote, getNotes } from '../db/notes';
import { config } from '../config';
import { getAuthorizationUrl, exchangeCodeForToken, getUserInfo } from './auth';

declare module 'express-session' {
  interface SessionData {
    slackId?: string;
    name?: string;
    isAuthorized?: boolean;
  }
}

function requireAuth(req: express.Request, res: express.Response, next: express.NextFunction): void {
  if (req.session?.isAuthorized) {
    next();
    return;
  }
  res.redirect('/auth/login');
}

let slackApp: App | null = null;
const userNameCache = new Map<string, string>();
let userCacheLoaded = false;
let userCacheLoading = false;

export async function initUserNameCache(): Promise<void> {
  if (!slackApp || userCacheLoading) return;
  userCacheLoading = true;
  console.log('[web] Building user name cache from Slack...');
  try {
    let cursor: string | undefined;
    let pages = 0;
    do {
      const resp: any = await slackApp.client.users.list({
        limit: 200,
        ...(cursor ? { cursor } : {}),
      });
      const members = resp.members || [];
      for (const m of members) {
        userNameCache.set(
          m.id,
          m.profile?.display_name || m.profile?.real_name || m.real_name || m.name || m.id,
        );
      }
      cursor = resp.response_metadata?.next_cursor;
      pages++;
      if (cursor) {
        console.log(`[web] Cached page ${pages} (${userNameCache.size} users), waiting 2s...`);
        await new Promise((r) => setTimeout(r, 2000));
      }
    } while (cursor);
    userCacheLoaded = true;
    console.log(`[web] User name cache ready: ${userNameCache.size} users across ${pages} pages`);
  } catch (err) {
    console.error('[web] Failed to build user cache:', err);
  } finally {
    userCacheLoading = false;
  }
}

async function lookupSlackNames(userIds: string[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();

  const missing = userIds.filter((id) => !userNameCache.has(id));

  if (missing.length > 0 && slackApp) {
    try {
      const batch = missing.map(async (id) => {
        try {
          const resp = await (slackApp!.client as any).users.info({ user: id });
          if (resp.user) {
            const u = resp.user as any;
            const name = u.profile?.display_name || u.profile?.real_name || u.real_name || u.name || id;
            userNameCache.set(id, name);
          }
        } catch (e) { /* skip */ }
      });
      await Promise.all(batch);
    } catch (err) {
      console.error('[web] Failed to look up missing users:', err);
    }
  }

  for (const id of userIds) {
    result.set(id, userNameCache.get(id) || id);
  }
  return result;
}

function escapeHtmlInline(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function ticketPageHtml(ticket: any): string {
  const st = ticket.status;
  const btnLabel = st === 'open' ? 'Resolve' : 'Reopen';
  const btnAction = st === 'open' ? 'resolve' : 'reopen';
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Ticket #${ticket.ticket_number} — Support</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;min-height:100vh;font-size:14px}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.85);pointer-events:none;z-index:-1}
.top{background:rgba(0,0,0,0.8);backdrop-filter:blur(8px);padding:12px 24px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid rgba(255,255,255,0.08)}
.top a{color:#aaa;text-decoration:none;font-size:13px}
.top a:hover{color:#fff}
.top h1{font-size:16px;color:#fff}
.cont{max-width:800px;margin:0 auto;padding:24px;position:relative;z-index:1}
.header{background:rgba(255,255,255,0.04);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.08);border-radius:8px;padding:16px 20px;margin-bottom:20px;display:flex;justify-content:space-between;align-items:center}
.header .info{display:flex;flex-direction:column;gap:4px}
.header .info .tnum{font-size:18px;font-weight:700;color:#fff}
.header .info .meta{font-size:13px;color:#888}
.header .badge{font-size:13px;padding:3px 10px;border-radius:4px;font-weight:600}
.badge.open{background:rgba(255,255,255,0.1);color:#fff}
.badge.resolved{background:rgba(255,255,255,0.04);color:#888}
.action-btn{padding:8px 20px;border-radius:4px;border:none;cursor:pointer;font-size:14px;font-weight:600;transition:background .15s}
.action-btn.resolve{background:rgba(255,255,255,0.12);color:#fff}
.action-btn.resolve:hover{background:rgba(255,255,255,0.2)}
.action-btn.reopen{background:rgba(255,255,255,0.06);color:#ccc;border:1px solid rgba(255,255,255,0.12)}
.action-btn.reopen:hover{background:rgba(255,255,255,0.15);color:#fff}
.thread-list{background:rgba(255,255,255,0.03);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.06);border-radius:8px;padding:16px;margin-bottom:20px;max-height:500px;overflow-y:auto}
.msg{padding:10px 12px;margin-bottom:6px;border-radius:6px;background:rgba(255,255,255,0.04);line-height:1.5}
.msg .author{font-weight:700;color:#ccc;font-size:13px;margin-bottom:3px}
.msg .author .time{font-weight:400;color:#555;font-size:11px;margin-left:8px}
.msg .body{white-space:pre-wrap;word-break:break-word;color:#fff;font-size:14px}
.send-box{display:flex;gap:10px;align-items:flex-start;background:rgba(255,255,255,0.03);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.06);border-radius:8px;padding:16px}
.send-box textarea{flex:1;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.1);color:#fff;padding:10px;border-radius:6px;font-size:14px;resize:vertical;min-height:48px;font-family:inherit}
.send-box textarea:focus{outline:0;border-color:rgba(255,255,255,0.2)}
.send-actions{display:flex;flex-direction:column;gap:8px;align-items:center}
.anon-label{display:flex;align-items:center;gap:4px;font-size:12px;color:#888;cursor:pointer;white-space:nowrap}
.send-btn{background:rgba(255,255,255,0.12);color:#fff;border:none;padding:8px 20px;border-radius:4px;cursor:pointer;font-size:14px;font-weight:700}
.send-btn:hover{background:rgba(255,255,255,0.2)}
.send-btn:disabled{opacity:0.4;cursor:default}
.empty{color:#555;padding:24px;text-align:center}
</style>
</head>
<body>
<div class="top">
  <a href="/">&larr; Back to Dashboard</a>
  <h1>Ticket #${ticket.ticket_number}</h1>
  <div><span id="userName">...</span></div>
</div>
<div class="cont">
  <div class="header">
    <div class="info">
      <div class="tnum">#${ticket.ticket_number} <span class="badge ${st}" id="ticketStatus">${st}</span></div>
      <div class="meta">Created ${new Date(ticket.created_at).toLocaleString()} by ${escapeHtmlInline((ticket as any).user_name || ticket.user_id)}</div>
      ${ticket.resolved_at ? '<div class="meta">Resolved ' + new Date(ticket.resolved_at).toLocaleString() + ' by ' + escapeHtmlInline(ticket.resolved_by) + '</div>' : ''}
    </div>
    <button class="action-btn ${btnAction}" id="actionBtn" onclick="toggleStatus()">${btnLabel}</button>
  </div>

  <div class="thread-list" id="messages">
    <div class="empty">Loading messages...</div>
  </div>

  <div class="send-box">
    <textarea id="msgInput" placeholder="Type a reply..." rows="2"></textarea>
    <div class="send-actions">
      <label class="anon-label"><input type="checkbox" id="sendAnon"> Anonymous</label>
      <button class="send-btn" onclick="sendMsg()">Send</button>
    </div>
  </div>
</div>

<script>
const ticketNumber = ${ticket.ticket_number};
const threadTs = "${escapeHtmlInline(ticket.thread_ts)}";
let currentStatus = "${st}";

function d(s) { return new Date(s).toLocaleString(); }

async function load() {
  try {
    const m = await fetch('/auth/me').then(r=>r.json());
    document.getElementById('userName').textContent = m.name||'';
  } catch(e) {}

  try {
    const msgs = await fetch('/api/tickets/'+threadTs+'/messages').then(r=>r.json());
    const el = document.getElementById('messages');
    if (!msgs.length) {
      el.innerHTML = '<div class="empty">No messages yet.</div>';
    } else {
      let h = '';
      for (const m of msgs) {
        const author = m.isBot ? 'Bot' : m.user;
        h += '<div class="msg"><div class="author">'+esc(author)+'<span class="time">'+d(m.ts)+'</span></div><div class="body">'+esc(m.text||'')+'</div></div>';
      }
      el.innerHTML = h;
      el.scrollTop = el.scrollHeight;
    }
  } catch(e) {
    document.getElementById('messages').innerHTML = '<div class="empty">Failed to load messages.</div>';
  }
}

async function toggleStatus() {
  const endpoint = currentStatus === 'open' ? 'resolve' : 'reopen';
  await fetch('/api/tickets/'+threadTs+'/'+endpoint,{method:'POST'});
  location.reload();
}

async function sendMsg() {
  const input = document.getElementById('msgInput');
  const msg = input.value.trim();
  if (!msg) return;
  const anon = document.getElementById('sendAnon').checked;
  const btn = document.querySelector('.send-btn');
  btn.disabled = true; btn.textContent = '...';
  try {
    await fetch('/api/tickets/'+threadTs+'/send',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({message:msg, anonymous:anon})
    });
    input.value = '';
    load();
  } catch(e) { alert('Failed to send'); }
  btn.disabled = false; btn.textContent = 'Send';
}

document.getElementById('msgInput').addEventListener('keydown', function(e) {
  if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMsg(); }
});

function esc(t) { const e=document.createElement('div');e.textContent=t;return e.innerHTML; }

load();
</script>
</body></html>`;
}

export function createWebServer(app?: App): express.Application {
  if (app) slackApp = app;

  const web = express();
  web.use(express.json());
  web.use(express.urlencoded({ extended: true }));
  web.use(express.static(path.join(__dirname, '..', '..', 'frontend', 'build')));
  web.use((_req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (_req.method === 'OPTIONS') {
      res.sendStatus(200);
      return;
    }
    next();
  });
  web.use(
    session({
      secret: config.web.sessionSecret,
      resave: false,
      saveUninitialized: false,
      cookie: {
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        sameSite: process.env.NODE_ENV === 'production' ? 'none' : 'lax',
        maxAge: 24 * 60 * 60 * 1000,
      },
    }),
  );

  web.get('/auth/login', (_req, res) => {
    res.send(loginPageHtml());
  });

  web.get('/auth/hc', (_req, res) => {
    res.redirect(getAuthorizationUrl());
  });

  web.get('/auth/callback', async (req, res) => {
    const code = (req.query.code as string) || '';
    if (!code) {
      res.status(400).send('Missing authorization code.');
      return;
    }

    const accessToken = await exchangeCodeForToken(code);
    if (!accessToken) {
      res.status(500).send('Failed to authenticate with Hack Club.');
      return;
    }

    const user = await getUserInfo(accessToken);
    if (!user || !user.slackId) {
      res.status(500).send('Failed to retrieve user info from Hack Club.');
      return;
    }

    const slackId = user.slackId;
    const displayName = user.name || slackId;

    const isOwner = slackId === config.slack.ownerUserId;
    const isAdmin = config.slack.adminUserIds.includes(slackId);
    const isSupport = isStaffMember(slackId);

    if (!isOwner && !isAdmin && !isSupport) {
      res.status(403).send(deniedHtml(displayName));
      return;
    }

    req.session.slackId = slackId;
    req.session.name = displayName;
    req.session.isAuthorized = true;

    logAudit(slackId, displayName, 'login', `Logged in via Hack Club${isOwner ? ' (owner)' : isAdmin ? ' (admin)' : ''}`);
    console.log(`[audit] Login: ${displayName} (${slackId})`);

    res.redirect('/');
  });

  web.get('/auth/logout', (req, res) => {
    const slId = req.session.slackId;
    const nm = req.session.name;
    req.session.regenerate((err) => {
      if (slId) logAudit(slId, nm || slId, 'logout', 'Logged out');
      res.send(logoutPageHtml());
    });
  });

  web.get('/auth/me', requireAuth, (req, res) => {
    res.json({ name: req.session.name, slackId: req.session.slackId });
  });

  web.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  web.get('/api/stats', requireAuth, (_req, res) => {
    res.json(getTicketStats());
  });

  web.get('/api/daily-stats', requireAuth, (_req, res) => {
    res.json(getDailyStats());
  });

  web.get('/api/tickets', requireAuth, async (req, res) => {
    const limit = parseInt((req.query.limit as string) || '20', 10);
    const offset = parseInt((req.query.offset as string) || '0', 10);
    const tickets = getAllTickets(limit, offset);
    const userIds = [...new Set(tickets.map((t) => t.user_id))];
    const names = await lookupSlackNames(userIds);
    const enriched = tickets.map((t) => ({ ...t, user_name: names.get(t.user_id) || t.user_id }));
    res.json(enriched);
  });

  web.get('/api/tickets/number/:number', requireAuth, (req, res) => {
    const num = parseInt(req.params.number as string, 10);
    if (isNaN(num)) {
      res.status(400).json({ error: 'Invalid ticket number' });
      return;
    }
    const ticket = getTicketByNumber(num);
    if (!ticket) {
      res.status(404).json({ error: 'Ticket not found' });
      return;
    }
    res.json(ticket);
  });

  web.post('/api/tickets/:threadTs/resolve', requireAuth, async (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) {
      res.status(404).json({ error: 'Ticket not found' });
      return;
    }
    if (ticket.status === 'resolved') {
      res.json({ ok: true, message: 'Already resolved' });
      return;
    }
    const resolverId = req.session.slackId || 'web';
    const resolverName = req.session.name || resolverId;
    resolveTicket(threadTs, resolverId);
    logAudit(resolverId, resolverName, 'resolve', `Resolved ticket #${ticket.ticket_number} from web`);

    if (slackApp) {
      try {
        await slackApp.client.chat.postMessage({
          channel: ticket.channel_id,
          thread_ts: ticket.thread_ts,
          text: ':white_check_mark: This has been marked as resolved. If your question hasn\'t been answered please reply back to reopen this ticket.',
        });
      } catch (err) {
        console.error('[web] Failed to post resolve message to Slack:', err);
      }
    }

    res.json({ ok: true });
  });

  web.post('/api/tickets/:threadTs/reopen', requireAuth, async (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) {
      res.status(404).json({ error: 'Ticket not found' });
      return;
    }
    if (ticket.status === 'open') {
      res.json({ ok: true, message: 'Already open' });
      return;
    }
    const reopenerId = req.session.slackId || 'web';
    const reopenerName = req.session.name || reopenerId;
    reopenTicket(threadTs);
    logAudit(reopenerId, reopenerName, 'reopen', `Reopened ticket #${ticket.ticket_number} from web`);

    if (slackApp) {
      try {
        await slackApp.client.chat.postMessage({
          channel: ticket.channel_id,
          thread_ts: ticket.thread_ts,
          text: ':arrows_counterclockwise: This ticket has been reopened.',
        });
      } catch (err) {
        console.error('[web] Failed to post reopen message to Slack:', err);
      }
    }

    res.json({ ok: true });
  });

  web.get('/api/support/team', requireAuth, async (_req, res) => {
    try {
      const members = getAllSupportMembers();
      const ids = members.map((m) => m.user_id);
      const names = await lookupSlackNames(ids);
      const result = members.map((m) => ({
        ...m,
        name: names.get(m.user_id) || m.user_id,
      }));
      res.json(result);
    } catch (err) {
      console.error('[web] /api/support/team error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  web.get('/api/tickets/:threadTs/messages', requireAuth, async (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) {
      res.status(404).json({ error: 'Ticket not found' });
      return;
    }
    if (!slackApp) {
      res.json([]);
      return;
    }
    try {
      const result = await slackApp.client.conversations.replies({
        channel: ticket.channel_id,
        ts: threadTs,
        limit: 50,
      });
      const messages = ((result as any).messages || []).map((m: any) => ({
        ts: m.ts,
        user: m.user || m.bot_id,
        text: m.text || '',
        isBot: !!m.bot_id,
      }));
      res.json(messages);
    } catch (err) {
      console.error('[web] Failed to fetch thread messages:', err);
      res.status(500).json({ error: 'Failed to fetch messages' });
    }
  });

  web.post('/api/tickets/:threadTs/send', requireAuth, async (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) {
      res.status(404).json({ error: 'Ticket not found' });
      return;
    }
    updateLastActivity(threadTs);
    if (!slackApp) {
      res.status(500).json({ error: 'Slack not connected' });
      return;
    }

    const { message, anonymous } = req.body || {};
    if (!message || typeof message !== 'string' || !message.trim()) {
      res.status(400).json({ error: 'Message is required' });
      return;
    }

    const senderName = req.session.name || req.session.slackId || 'Support';

    try {
      if (anonymous) {
        await slackApp.client.chat.postMessage({
          channel: ticket.channel_id,
          thread_ts: threadTs,
          text: message.trim(),
        });
      } else {
        await slackApp.client.chat.postMessage({
          channel: ticket.channel_id,
          thread_ts: threadTs,
          text: message.trim(),
          blocks: [
            {
              type: 'section',
              text: { type: 'mrkdwn', text: message.trim() },
            },
            {
              type: 'context',
              elements: [
                {
                  type: 'mrkdwn',
                  text: `_Sent by ${senderName} · Heist Support_`,
                },
              ],
            },
          ],
        });
      }
      res.json({ ok: true });
    } catch (err) {
      console.error('[web] Failed to send message:', err);
      res.status(500).json({ error: 'Failed to send message' });
    }
  });

  web.get('/ticket/:number', requireAuth, async (_req, res) => {
    const num = parseInt(_req.params.number as string, 10);
    const ticket = getTicketByNumber(num);
    if (!ticket) {
      res.status(404).send('<p>Ticket not found. <a href="/">Back</a></p>');
      return;
    }
    const names = await lookupSlackNames([ticket.user_id]);
    (ticket as any).user_name = names.get(ticket.user_id) || ticket.user_id;
    res.send(ticketPageHtml(ticket));
  });

  web.get('/api/stats/leaderboard', requireAuth, async (_req, res) => {
    try {
      const resolvers = getTopResolvers(10);
      const creators = getTopCreators(10);
      const resolverIds = resolvers.map((r) => r.userId);
      const creatorIds = creators.map((c) => c.userId);
      const names = await lookupSlackNames([...resolverIds, ...creatorIds]);
      res.json({
        resolvers: resolvers.map((r) => ({ ...r, name: names.get(r.userId) || r.userId })),
        creators: creators.map((c) => ({ ...c, name: names.get(c.userId) || c.userId })),
      });
    } catch (err) {
      res.status(500).json({ error: 'Failed to load leaderboard' });
    }
  });

  web.get('/api/stats/detail', requireAuth, (_req, res) => {
    try {
      res.json({
        avgResponseTime: getAvgResponseTime(),
        byWeekday: getTicketCountByWeekday(),
      });
    } catch (err) {
      console.error('[web] Stats detail error:', err);
      res.json({ avgResponseTime: null, byWeekday: [] });
    }
  });

  web.get('/api/tickets/mine', requireAuth, async (req, res) => {
    if (!req.session.slackId) { res.json([]); return; }
    const tickets = getMyTickets(req.session.slackId);
    const userIds = [...new Set(tickets.map((t) => t.user_id))];
    const names = await lookupSlackNames(userIds);
    res.json(tickets.map((t) => ({ ...t, user_name: names.get(t.user_id) || t.user_id })));
  });

  web.post('/api/tickets/:threadTs/assign', requireAuth, async (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) { res.status(404).json({ error: 'Ticket not found' }); return; }
    const assigneeId = req.body?.userId;
    if (!assigneeId) { res.status(400).json({ error: 'userId required' }); return; }
    if (ticket.status !== 'open') { res.status(400).json({ error: 'Can only assign open tickets' }); return; }

    assignTicket(threadTs, assigneeId);
    logAudit(req.session.slackId || '', req.session.name || '', 'assign', `Assigned ticket #${ticket.ticket_number} to ${assigneeId}`);

    res.json({ ok: true });
  });

  web.get('/api/tickets/oldest', requireAuth, async (_req, res) => {
    const tickets = getOldestOpen(5);
    const userIds = [...new Set(tickets.map((t) => t.user_id))];
    const names = await lookupSlackNames(userIds);
    res.json(tickets.map((t) => ({ ...t, user_name: names.get(t.user_id) || t.user_id })));
  });

  web.get('/api/tickets/:threadTs/notes', requireAuth, (_req, res) => {
    res.json(getNotes(_req.params.threadTs as string));
  });

  web.post('/api/tickets/:threadTs/notes', requireAuth, (req, res) => {
    const threadTs = req.params.threadTs as string;
    const ticket = getTicket(threadTs);
    if (!ticket) { res.status(404).json({ error: 'Ticket not found' }); return; }
    const note = req.body?.note;
    if (!note || typeof note !== 'string' || !note.trim()) {
      res.status(400).json({ error: 'Note text required' });
      return;
    }
    addNote(threadTs, req.session.slackId || '', req.session.name || '', note.trim());
    res.json({ ok: true });
  });

  web.get('/api/audit', requireAuth, (req, res) => {
    if (req.session.slackId !== config.slack.ownerUserId) {
      res.status(403).json({ error: 'Only the owner can view audit logs' });
      return;
    }
    const limit = parseInt((req.query.limit as string) || '100', 10);
    const offset = parseInt((req.query.offset as string) || '0', 10);
    const action = req.query.action as string | undefined;
    const fromDate = req.query.from as string | undefined;
    const toDate = req.query.to as string | undefined;
    const search = req.query.search as string | undefined;
    res.json(getAuditLogs(limit, offset, action, fromDate, toDate, search));
  });

  web.get('/stats', requireAuth, (_req, res) => {
    res.send(statsPageHtml());
  });

  web.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/auth')) {
      next();
      return;
    }
    res.sendFile(path.join(__dirname, '..', '..', 'frontend', 'build', 'index.html'));
  });

  web.get('/', requireAuth, (_req, res) => {
    res.send(dashboardHtml());
  });

  return web;
}

function loginPageHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Support — Login</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.88);pointer-events:none;z-index:-1}
.box{background:rgba(255,255,255,0.03);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:40px 50px;text-align:center;max-width:400px;width:90%}
.box h1{font-size:22px;color:#fff;margin-bottom:8px}
.box p{color:#888;font-size:14px;margin-bottom:24px}
.login-btn{display:inline-block;background:rgba(255,255,255,0.1);color:#fff;border:1px solid rgba(255,255,255,0.15);padding:12px 32px;border-radius:6px;font-size:15px;font-weight:600;text-decoration:none;cursor:pointer;transition:all .15s}
.login-btn:hover{background:rgba(255,255,255,0.18)}
</style>
</head>
<body>
<div class="box">
  <h1>Support Dashboard</h1>
  <p>Sign in with your Hack Club account</p>
  <a href="/auth/hc" class="login-btn">Login with Hack Club</a>
</div>
</body></html>`;
}

function logoutPageHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Support — Logged Out</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;min-height:100vh;display:flex;align-items:center;justify-content:center}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.88);pointer-events:none;z-index:-1}
.box{background:rgba(255,255,255,0.03);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:40px 50px;text-align:center;max-width:400px;width:90%}
.box h1{font-size:22px;color:#fff;margin-bottom:8px}
.box p{color:#888;font-size:14px;margin-bottom:24px}
.login-btn{display:inline-block;background:rgba(255,255,255,0.1);color:#fff;border:1px solid rgba(255,255,255,0.15);padding:12px 32px;border-radius:6px;font-size:15px;font-weight:600;text-decoration:none;cursor:pointer;transition:all .15s}
.login-btn:hover{background:rgba(255,255,255,0.18)}
</style>
</head>
<body>
<div class="box">
  <h1>Logged Out</h1>
  <p>You have been signed out.</p>
  <a href="/auth/hc" class="login-btn">Login with Hack Club</a>
</div>
</body></html>`;
}

function deniedHtml(name: string): string {
  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Access Denied</title>
<style>body{font-family:system-ui,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.88);pointer-events:none;z-index:-1}
h1{color:#fff}
h1{color:#e94560}</style></head>
<body><div><h1>Access Denied</h1><p>${name} — your Slack account is not on the support team.<br>Ask an admin to run <code>/support enable @you</code> in Slack.</p></div></body></html>`;
}

function dashboardHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Support Dashboard</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;min-height:100vh;font-size:14px}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.85);pointer-events:none;z-index:-1}
.top{background:rgba(0,0,0,0.8);backdrop-filter:blur(8px);padding:12px 28px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid rgba(255,255,255,0.08)}
.top h1{font-size:17px;color:#fff}
.top a{color:#aaa;text-decoration:none;margin-left:14px;font-size:13px}
.top a:hover{color:#fff}
.cont{max-width:1000px;margin:0 auto;padding:24px;position:relative;z-index:1}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:24px}
.card{background:rgba(255,255,255,0.04);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.08);padding:18px;border-radius:6px;text-align:center}
.card .n{font-size:32px;font-weight:700;color:#fff}
.card .l{font-size:12px;color:#888;margin-top:3px}
.panel{background:rgba(255,255,255,0.03);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.06);border-radius:6px;padding:18px;margin-bottom:22px}
.panel h2{font-size:15px;color:#ccc;margin-bottom:14px}
table{width:100%;border-collapse:collapse}
th,td{padding:8px 12px;text-align:left;font-size:13px;border-bottom:1px solid rgba(255,255,255,0.06)}
th{color:#888;font-weight:600}
tr.t-row{cursor:pointer;transition:background .15s}
tr.t-row:hover{background:rgba(255,255,255,0.04)}
.badge{padding:2px 7px;border-radius:3px;font-size:12px;font-weight:600}
.badge.open{background:rgba(255,255,255,0.1);color:#fff}
.badge.resolved{background:rgba(255,255,255,0.04);color:#888}
.btn{padding:4px 12px;border-radius:3px;border:none;cursor:pointer;font-size:12px;font-weight:600}
.btn.resolve{background:rgba(255,255,255,0.08);color:#ccc;border:1px solid rgba(255,255,255,0.15)}
.btn.resolve:hover{background:rgba(255,255,255,0.15);color:#fff}
.btn.reopen{background:rgba(255,255,255,0.12);color:#fff}
.btn.reopen:hover{background:rgba(255,255,255,0.2)}
.pages{display:flex;justify-content:center;gap:6px;margin-top:14px}
.pages button{padding:5px 12px;border:1px solid rgba(255,255,255,0.1);background:rgba(255,255,255,0.04);color:#ccc;border-radius:3px;cursor:pointer;font-size:12px}
.pages button.active{background:rgba(255,255,255,0.15);border-color:rgba(255,255,255,0.2);color:#fff}
.pages button:disabled{opacity:0.3;cursor:default}
.chart-wrap{height:260px}
.empty{color:#555;padding:24px;text-align:center;font-size:13px}
.err{color:#ff6b6b;padding:24px;text-align:center;font-size:13px}
.thread{padding:6px 8px;margin:4px 0;border-radius:4px;background:#0d1a32;font-size:12px}
.thread .author{color:#e94560;font-weight:600;margin-bottom:2px}
.thread .body{white-space:pre-wrap;word-break:break-word;color:#bbb}
.thread.me{background:#162840}
.send-box{display:flex;gap:8px;margin-top:12px;align-items:flex-start}
.send-box textarea{flex:1;background:#0d1a32;border:1px solid #0f3460;color:#ccc;padding:8px;border-radius:4px;font-size:12px;resize:vertical;min-height:36px;font-family:inherit}
.send-box textarea:focus{outline:0;border-color:#e94560}
.send-box .send-actions{display:flex;flex-direction:column;gap:6px;align-items:center}
.send-box .anon{display:flex;align-items:center;gap:4px;font-size:11px;color:#888;white-space:nowrap}
.send-box .anon input{cursor:pointer}
.send-send{background:#e94560;color:#fff;border:none;padding:6px 16px;border-radius:4px;cursor:pointer;font-size:12px;font-weight:600}
.send-send:hover{background:#c0392b}
.send-send:disabled{opacity:0.4;cursor:default}
</style>
</head>
<body>
<div class="top">
  <h1>Support</h1>
  <div class="user">
    <span id="userName">...</span>
    <a href="/stats">Stats</a>
    <a href="/auth/logout">Logout</a>
  </div>
</div>
<div class="cont">
  <div class="cards">
    <div class="card"><div class="n" id="total">-</div><div class="l">Total</div></div>
    <div class="card"><div class="n" id="open">-</div><div class="l">Open</div></div>
    <div class="card"><div class="n" id="resolved">-</div><div class="l">Resolved</div></div>
  </div>

  <div class="panel">
    <h2>Tickets Created vs Resolved</h2>
    <div class="chart-wrap"><canvas id="chart"></canvas></div>
  </div>

  <div class="panel">
    <h2>Recent Tickets</h2>
    <div id="ticketsTable"><div class="empty">Loading...</div></div>
    <div class="pages" id="pagination"></div>
  </div>

  <div class="panel">
    <h2>Support Team</h2>
    <div id="teamList"><div class="empty">Loading...</div></div>
  </div>
</div>

<script>
let chart = null;
let page = 0;
let tickets = [];
const perPage = 15;

function esc(t) { const e=document.createElement('div');e.textContent=t;return e.innerHTML; }
function d(s) { return new Date(s).toLocaleString(); }

async function loadChart(ds) {
  try {
    if (typeof Chart === 'undefined') {
      await new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js';
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
      });
    }
    if (chart) chart.destroy();
    const ctx = document.getElementById('chart').getContext('2d');
    chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ds.map(d=>d.date.slice(5)),
        datasets: [
          { label: 'Created', data: ds.map(d=>d.created), borderColor: '#fff', backgroundColor:'#ffffff22',fill:true,tension:0.2,pointRadius:1 },
          { label: 'Resolved', data: ds.map(d=>d.resolved), borderColor: '#888', backgroundColor:'#88888822',fill:true,tension:0.2,pointRadius:1 }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { labels: { color:'#888', font:{size:11} } } },
        scales: {
          x: { ticks: { color:'#666',font:{size:10},maxTicksLimit:12 },grid:{color:'#333'} },
          y: { ticks: { color:'#666',font:{size:10},beginAtZero:true,stepSize:1 },grid:{color:'#333'} }
        }
      }
    });
  } catch(e) { console.error('Chart failed:', e); }
}

async function resolveTicket(ts) {
  await fetch('/api/tickets/'+ts+'/resolve',{method:'POST'});
  load();
}
async function reopenTicket(ts) {
  await fetch('/api/tickets/'+ts+'/reopen',{method:'POST'});
  load();
}
function goPage(p) { page = p; load(); }
function goTicket(num) { window.location='/ticket/'+num; }

function renderTickets() {
  if (!tickets.length) {
    document.getElementById('ticketsTable').innerHTML = '<div class="empty">No tickets yet.</div>';
    return;
  }
  let html = '<table><thead><tr><th>#</th><th>User</th><th>Status</th><th>Created</th><th></th></tr></thead><tbody>';
  for (const t of tickets) {
    html += '<tr class="t-row" onclick="goTicket('+t.ticket_number+')">'
      + '<td>#' + t.ticket_number + '</td>'
      + '<td>' + esc(t.user_name || t.user_id) + '</td>'
      + '<td><span class="badge '+t.status+'">'+t.status+'</span></td>'
      + '<td>'+d(t.created_at)+'</td>'
      + '<td onclick="event.stopPropagation()">' + (t.status==='open'
          ? '<button class="btn resolve" onclick="resolveTicket(\\''+t.thread_ts+'\\')">Resolve</button>'
          : '<button class="btn reopen" onclick="reopenTicket(\\''+t.thread_ts+'\\')">Reopen</button>')
      + '</td></tr>';
  }
  html += '</tbody></table>';
  document.getElementById('ticketsTable').innerHTML = html;

  const total = parseInt(document.getElementById('total').textContent) || 0;
  const pages = Math.ceil(total / perPage) || 1;
  let ph = '';
  for (let i = 0; i < pages; i++) {
    ph += '<button class="'+(i===page?'active':'')+'" onclick="goPage('+i+')">'+(i+1)+'</button>';
  }
  document.getElementById('pagination').innerHTML = ph;
}

async function load() {
  try {
    const m = await fetch('/auth/me').then(r=>r.json());
    document.getElementById('userName').textContent = m.name||m.slackId;
  } catch(e) { console.error('auth/me failed:', e); }

  try {
    const s = await fetch('/api/stats').then(r=>r.json());
    document.getElementById('total').textContent = s.total;
    document.getElementById('open').textContent = s.open;
    document.getElementById('resolved').textContent = s.resolved;
  } catch(e) { document.getElementById('total').textContent = 'err'; }

  try {
    const ds = await fetch('/api/daily-stats').then(r=>r.json());
    await loadChart(ds);
  } catch(e) { console.error('chart failed:', e); }

  try {
    tickets = await fetch('/api/tickets?limit='+perPage+'&offset='+(page*perPage)).then(r=>r.json());
  } catch(e) { tickets = []; }
  renderTickets();

  try {
    const team = await fetch('/api/support/team').then(r=>r.json());
    if (!Array.isArray(team) || !team.length) {
      document.getElementById('teamList').innerHTML = '<div class="empty">No support team members yet. Add with /support enable @user in Slack.</div>';
    } else {
      let html = '<table><thead><tr><th>Name</th><th>User ID</th><th>Added By</th><th>Added</th></tr></thead><tbody>';
      for (const m of team) {
        html += '<tr><td>'+esc(m.name)+'</td><td>'+esc(m.user_id)+'</td><td>'+esc(m.added_by)+'</td><td>'+d(m.added_at)+'</td></tr>';
      }
      html += '</tbody></table>';
      document.getElementById('teamList').innerHTML = html;
    }
  } catch(e) { document.getElementById('teamList').innerHTML = '<div class="err">Failed to load team</div>'; }
}

load();
setInterval(load, 30000);
</script>
</body></html>`;
}

function statsPageHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Stats — Support</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a14 url(https://cdn.hackclub.com/019efbe9-dfb5-7efe-bf10-544a34a0fedd/abstract-perspective-graph-pattern-grid-vector-design_1017-45232.avif) center/cover fixed;color:#fff;min-height:100vh;font-size:14px}
body::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.85);pointer-events:none;z-index:-1}
.top{background:rgba(0,0,0,0.8);backdrop-filter:blur(8px);padding:12px 28px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid rgba(255,255,255,0.08)}
.top h1{font-size:17px;color:#fff}
.top nav a{color:#aaa;text-decoration:none;margin-left:14px;font-size:13px}
.top nav a:hover{color:#fff}
.cont{max-width:1000px;margin:0 auto;padding:24px;position:relative;z-index:1}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-bottom:22px}
.panel{background:rgba(255,255,255,0.03);backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,0.06);border-radius:6px;padding:18px}
.panel h2{font-size:15px;color:#ccc;margin-bottom:14px}
.chart-wrap{height:240px}
table{width:100%;border-collapse:collapse}
th,td{padding:7px 12px;text-align:left;font-size:13px;border-bottom:1px solid rgba(255,255,255,0.06)}
th{color:#888;font-weight:600}
td .bar{display:inline-block;height:8px;background:rgba(255,255,255,0.3);border-radius:2px;margin-left:8px;vertical-align:middle}
.stat-row{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.06);font-size:14px}
.stat-row .val{color:#fff;font-weight:700}
.empty{color:#555;padding:24px;text-align:center;font-size:13px}
@media(max-width:700px){.grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class="top">
  <h1>Support · Stats</h1>
  <nav>
    <a href="/">Dashboard</a>
    <a href="/auth/logout">Logout</a>
  </nav>
</div>
<div class="cont">
  <div class="grid">
    <div class="panel">
      <h2>Top Resolvers</h2>
      <div id="topResolvers"><div class="empty">Loading...</div></div>
    </div>
    <div class="panel">
      <h2>Top Creators</h2>
      <div id="topCreators"><div class="empty">Loading...</div></div>
    </div>
  </div>

  <div class="panel" style="margin-bottom:20px">
    <h2>Tickets by Day of Week</h2>
    <div class="chart-wrap"><canvas id="weekdayChart"></canvas></div>
  </div>

  <div class="panel">
    <h2>Summary</h2>
    <div id="summary"><div class="empty">Loading...</div></div>
  </div>
</div>

<script>
const dayNames = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

function esc(t){const e=document.createElement('div');e.textContent=t;return e.innerHTML}

async function load(){
  try{
    const lb = await fetch('/api/stats/leaderboard').then(r=>r.json());
    let h = '<table><thead><tr><th>#</th><th>Name</th><th>Resolved</th></tr></thead><tbody>';
    const maxR = lb.resolvers[0]?.count || 1;
    lb.resolvers.forEach((r,i) => {
      h += '<tr><td>'+(i+1)+'</td><td>'+esc(r.name)+'<span class="bar" style="width:'+(r.count/maxR*100)+'px"></span></td><td>'+r.count+'</td></tr>';
    });
    h += '</tbody></table>';
    document.getElementById('topResolvers').innerHTML = lb.resolvers.length ? h : '<div class="empty">No resolutions yet.</div>';

    h = '<table><thead><tr><th>#</th><th>Name</th><th>Tickets</th></tr></thead><tbody>';
    const maxC = lb.creators[0]?.count || 1;
    lb.creators.forEach((c,i) => {
      h += '<tr><td>'+(i+1)+'</td><td>'+esc(c.name)+'<span class="bar" style="width:'+(c.count/maxC*100)+'px"></span></td><td>'+c.count+'</td></tr>';
    });
    h += '</tbody></table>';
    document.getElementById('topCreators').innerHTML = lb.creators.length ? h : '<div class="empty">No tickets yet.</div>';
  }catch(e){ console.error('leaderboard failed:', e); }

  try{
    const ds = await fetch('/api/stats/detail').then(r=>r.json());
    const ctx = document.getElementById('weekdayChart').getContext('2d');
    const byWeekday = Array.isArray(ds.byWeekday) ? ds.byWeekday : [];
    new Chart(ctx,{
      type:'bar',
      data:{
        labels:dayNames,
        datasets:[{
          label:'Tickets',
          data:dayNames.map((_,i)=>{const d=byWeekday.find((w)=>w.weekday===i);return d?d.count:0}),
          backgroundColor:'rgba(255,255,255,0.2)'
        }]
      },
      options:{
        responsive:true,maintainAspectRatio:false,
        plugins:{legend:{labels:{color:'#888',font:{size:11}}}},
        scales:{
          x:{ticks:{color:'#666',font:{size:10}},grid:{color:'#333'}},
          y:{ticks:{color:'#666',font:{size:10},beginAtZero:true,stepSize:1},grid:{color:'#333'}}
        }
      }
    });

    let sum = '';
    if(ds.avgResponseTime){
      sum += '<div class="stat-row"><span>Avg Response Time</span><span class="val">'+ds.avgResponseTime.avgHours+' hours</span></div>';
    } else {
      sum += '<div class="stat-row"><span>Avg Response Time</span><span class="val">N/A</span></div>';
    }
    const totalTickets = byWeekday.reduce((a,b)=>a+b.count,0);
    sum += '<div class="stat-row"><span>Total Tickets</span><span class="val">'+totalTickets+'</span></div>';
    const busiest = byWeekday.reduce((a,b)=>b.count>a.count?b:a,{weekday:0,count:0});
    sum += '<div class="stat-row"><span>Busiest Day</span><span class="val">'+dayNames[busiest.weekday]+'</span></div>';
    document.getElementById('summary').innerHTML = sum;
  }catch(e){
    console.error('Stats detail failed:', e);
    document.getElementById('summary').innerHTML = '<div class="stat-row"><span>Could not load summary</span></div>';
  }
}

load();
</script>
</body></html>`;
}
