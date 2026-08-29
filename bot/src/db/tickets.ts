import { getDb } from './database';

export interface Ticket {
  thread_ts: string;
  channel_id: string;
  user_id: string;
  status: 'open' | 'resolved';
  ticket_number: number;
  created_at: string;
  resolved_at: string | null;
  resolved_by: string | null;
  claimed_by: string | null;
  claimed_at: string | null;
}

export function createTicket(
  threadTs: string,
  channelId: string,
  userId: string,
): Ticket {
  const db = getDb();
  const now = new Date().toISOString();
  const max = (
    db.prepare('SELECT COALESCE(MAX(ticket_number), 0) + 1 as next FROM tickets').get() as {
      next: number;
    }
  ).next;
  db.prepare(
    `INSERT OR IGNORE INTO tickets (thread_ts, channel_id, user_id, status, created_at, ticket_number)
     VALUES (?, ?, ?, 'open', ?, ?)`,
  ).run(threadTs, channelId, userId, now, max);
  return getTicket(threadTs)!;
}

export function getTicket(threadTs: string): Ticket | undefined {
  const db = getDb();
  return db
    .prepare('SELECT * FROM tickets WHERE thread_ts = ?')
    .get(threadTs) as Ticket | undefined;
}

export function getTicketByNumber(number: number): Ticket | undefined {
  const db = getDb();
  return db
    .prepare('SELECT * FROM tickets WHERE ticket_number = ?')
    .get(number) as Ticket | undefined;
}

export function resolveTicket(threadTs: string, resolvedBy: string): void {
  const db = getDb();
  const now = new Date().toISOString();
  db.prepare(
    `UPDATE tickets SET status = 'resolved', resolved_at = ?, resolved_by = ? WHERE thread_ts = ?`,
  ).run(now, resolvedBy, threadTs);
}

export function reopenTicket(threadTs: string): void {
  const db = getDb();
  db.prepare(
    `UPDATE tickets SET status = 'open', resolved_at = NULL, resolved_by = NULL WHERE thread_ts = ?`,
  ).run(threadTs);
}

export function getTicketStats(): { total: number; open: number; resolved: number } {
  const db = getDb();
  const total = (
    db.prepare('SELECT COUNT(*) as count FROM tickets').get() as { count: number }
  ).count;
  const open = (
    db.prepare("SELECT COUNT(*) as count FROM tickets WHERE status = 'open'").get() as {
      count: number;
    }
  ).count;
  const resolved = (
    db.prepare("SELECT COUNT(*) as count FROM tickets WHERE status = 'resolved'").get() as {
      count: number;
    }
  ).count;
  return { total, open, resolved };
}

export function getAllTickets(limit = 50, offset = 0): Ticket[] {
  const db = getDb();
  return db
    .prepare(
      'SELECT * FROM tickets ORDER BY created_at DESC LIMIT ? OFFSET ?',
    )
    .all(limit, offset) as Ticket[];
}

export interface DailyStat {
  date: string;
  created: number;
  resolved: number;
}

export function getDailyStats(): DailyStat[] {
  const db = getDb();
  const created = db
    .prepare(
      "SELECT date(created_at) as date, COUNT(*) as count FROM tickets GROUP BY date ORDER BY date",
    )
    .all() as { date: string; count: number }[];
  const resolved = db
    .prepare(
      "SELECT date(resolved_at) as date, COUNT(*) as count FROM tickets WHERE resolved_at IS NOT NULL GROUP BY date ORDER BY date",
    )
    .all() as { date: string; count: number }[];

  const map = new Map<string, { created: number; resolved: number }>();
  for (const row of created) {
    map.set(row.date, { created: row.count, resolved: 0 });
  }
  for (const row of resolved) {
    const entry = map.get(row.date) || { created: 0, resolved: 0 };
    entry.resolved += row.count;
    map.set(row.date, entry);
  }

  return Array.from(map.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, v]) => ({ date, ...v }));
}

export interface LeaderboardEntry {
  userId: string;
  count: number;
}

export function getTopCreators(limit = 10): LeaderboardEntry[] {
  const db = getDb();
  return db
    .prepare(
      'SELECT user_id as userId, COUNT(*) as count FROM tickets GROUP BY user_id ORDER BY count DESC LIMIT ?',
    )
    .all(limit) as LeaderboardEntry[];
}

export function getTopResolvers(limit = 10): LeaderboardEntry[] {
  const db = getDb();
  return db
    .prepare(
      "SELECT resolved_by as userId, COUNT(*) as count FROM tickets WHERE resolved_by IS NOT NULL GROUP BY resolved_by ORDER BY count DESC LIMIT ?",
    )
    .all(limit) as LeaderboardEntry[];
}

export function getTicketCountByWeekday(): { weekday: number; count: number }[] {
  const db = getDb();
  return db
    .prepare(
      "SELECT CAST(strftime('%w', created_at) AS INTEGER) as weekday, COUNT(*) as count FROM tickets GROUP BY weekday ORDER BY weekday",
    )
    .all() as { weekday: number; count: number }[];
}

export function getAvgResponseTime(): { avgHours: number } | null {
  const db = getDb();
  const row = db
    .prepare(
      "SELECT ROUND(AVG((julianday(resolved_at) - julianday(created_at)) * 24), 1) as avgHours FROM tickets WHERE resolved_at IS NOT NULL",
    )
    .get() as { avgHours: number } | undefined;
  return row?.avgHours != null ? { avgHours: row.avgHours } : null;
}

export function getOldestOpen(limit = 5): Ticket[] {
  const db = getDb();
  return db
    .prepare("SELECT * FROM tickets WHERE status = 'open' ORDER BY created_at ASC LIMIT ?")
    .all(limit) as Ticket[];
}

export function getStaleClaimed(days = 3): Ticket[] {
  const db = getDb();
  return db
    .prepare(
      `SELECT * FROM tickets WHERE status = 'open' AND claimed_by IS NOT NULL
       AND julianday('now') - julianday(COALESCE(last_activity_at, created_at)) >= ?`,
    )
    .all(days) as Ticket[];
}

export function updateLastActivity(threadTs: string): void {
  const db = getDb();
  const now = new Date().toISOString();
  db.prepare('UPDATE tickets SET last_activity_at = ? WHERE thread_ts = ?').run(now, threadTs);
}

export function assignTicket(threadTs: string, userId: string): void {
  const db = getDb();
  const now = new Date().toISOString();
  db.prepare('UPDATE tickets SET claimed_by = ?, claimed_at = ? WHERE thread_ts = ?').run(
    userId,
    now,
    threadTs,
  );
}

export function getMyTickets(userId: string): Ticket[] {
  const db = getDb();
  return db
    .prepare("SELECT * FROM tickets WHERE claimed_by = ? AND status = 'open' ORDER BY created_at ASC LIMIT 20")
    .all(userId) as Ticket[];
}
