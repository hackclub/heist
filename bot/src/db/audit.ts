import { getDb } from './database';

export interface AuditLog {
  id: number;
  timestamp: string;
  user_id: string;
  user_name: string;
  action: string;
  details: string;
}

export function logAudit(
  userId: string,
  userName: string,
  action: string,
  details: string = '',
): void {
  const db = getDb();
  const now = new Date().toISOString();
  db.prepare(
    'INSERT INTO audit_logs (timestamp, user_id, user_name, action, details) VALUES (?, ?, ?, ?, ?)',
  ).run(now, userId, userName, action, details);
}

export function getAuditLogs(
  limit = 100,
  offset = 0,
  action?: string,
  fromDate?: string,
  toDate?: string,
  search?: string,
): AuditLog[] {
  const db = getDb();
  const clauses: string[] = [];
  const params: (string | number)[] = [];

  if (action && action !== 'all') {
    clauses.push('action = ?');
    params.push(action);
  }
  if (fromDate) {
    clauses.push('timestamp >= ?');
    params.push(fromDate);
  }
  if (toDate) {
    // Add one day to include the full end date
    clauses.push('timestamp < ?');
    params.push(toDate + 'T23:59:59.999Z');
  }
  if (search) {
    clauses.push('(user_name LIKE ? OR details LIKE ?)');
    params.push(`%${search}%`, `%${search}%`);
  }

  const where = clauses.length > 0 ? 'WHERE ' + clauses.join(' AND ') : '';
  params.push(limit, offset);

  return db
    .prepare(`SELECT * FROM audit_logs ${where} ORDER BY id DESC LIMIT ? OFFSET ?`)
    .all(...params) as AuditLog[];
}
