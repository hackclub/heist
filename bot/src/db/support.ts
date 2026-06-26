import { getDb } from './database';

export interface SupportMember {
  user_id: string;
  added_by: string;
  added_at: string;
}

export function addSupportMember(userId: string, addedBy: string): boolean {
  const db = getDb();
  const now = new Date().toISOString();
  const result = db
    .prepare(
      `INSERT OR IGNORE INTO support_team (user_id, added_by, added_at) VALUES (?, ?, ?)`,
    )
    .run(userId, addedBy, now);
  return result.changes > 0;
}

export function removeSupportMember(userId: string): boolean {
  const db = getDb();
  const result = db
    .prepare('DELETE FROM support_team WHERE user_id = ?')
    .run(userId);
  return result.changes > 0;
}

export function isSupportMember(userId: string): boolean {
  const db = getDb();
  const row = db
    .prepare('SELECT user_id FROM support_team WHERE user_id = ?')
    .get(userId);
  return !!row;
}

export function getAllSupportMembers(): SupportMember[] {
  const db = getDb();
  return db
    .prepare('SELECT * FROM support_team ORDER BY added_at ASC')
    .all() as SupportMember[];
}

export function addAdmin(userId: string, addedBy: string): boolean {
  const db = getDb();
  const now = new Date().toISOString();
  const result = db
    .prepare('INSERT OR IGNORE INTO admins (user_id, added_by, added_at) VALUES (?, ?, ?)')
    .run(userId, addedBy, now);
  addSupportMember(userId, addedBy);
  return result.changes > 0;
}

export function removeAdmin(userId: string): boolean {
  const db = getDb();
  const result = db.prepare('DELETE FROM admins WHERE user_id = ?').run(userId);
  return result.changes > 0;
}

export function isAdminMember(userId: string): boolean {
  const db = getDb();
  const row = db.prepare('SELECT user_id FROM admins WHERE user_id = ?').get(userId);
  return !!row;
}

export function isStaffMember(userId: string): boolean {
  return isSupportMember(userId) || isAdminMember(userId);
}

export function seedAdminsFromEnv(): void {
  const ids = require('../config').config.slack.adminUserIds;
  if (!ids || ids.length === 0) return;
  const db = getDb();
  const now = new Date().toISOString();
  const insert = db.prepare('INSERT OR IGNORE INTO admins (user_id, added_by, added_at) VALUES (?, ?, ?)');
  const support = db.prepare('INSERT OR IGNORE INTO support_team (user_id, added_by, added_at) VALUES (?, ?, ?)');
  for (const id of ids) {
    insert.run(id, 'env_seed', now);
    support.run(id, 'env_seed', now);
  }
}
