import Database from 'better-sqlite3';
import path from 'path';

const DB_PATH = path.join(__dirname, '..', 'data', 'heist_support.db');

let db: Database.Database;

export function getDb(): Database.Database {
  if (!db) {
    const fs = require('fs');
    const dir = path.dirname(DB_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initializeDb(db);
  }
  return db;
}

function addColumnIfMissing(db: Database.Database, table: string, column: string, type: string): void {
  const exists = db
    .prepare(`SELECT COUNT(*) as cnt FROM pragma_table_info(?) WHERE name = ?`)
    .get(table, column) as { cnt: number };
  if (exists.cnt === 0) {
    db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`);
  }
}

function initializeDb(db: Database.Database): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS tickets (
      thread_ts TEXT PRIMARY KEY,
      channel_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'open',
      created_at TEXT NOT NULL,
      resolved_at TEXT,
      resolved_by TEXT
    );

    CREATE TABLE IF NOT EXISTS support_team (
      user_id TEXT PRIMARY KEY,
      added_by TEXT NOT NULL,
      added_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS admins (
      user_id TEXT PRIMARY KEY,
      added_by TEXT NOT NULL,
      added_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      action TEXT NOT NULL,
      details TEXT NOT NULL DEFAULT ''
    );

    CREATE TABLE IF NOT EXISTS internal_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      thread_ts TEXT NOT NULL,
      author_id TEXT NOT NULL,
      author_name TEXT NOT NULL,
      note TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (thread_ts) REFERENCES tickets(thread_ts)
    );
  `);

  addColumnIfMissing(db, 'tickets', 'ticket_number', 'INTEGER');
  addColumnIfMissing(db, 'tickets', 'claimed_by', 'TEXT');
  addColumnIfMissing(db, 'tickets', 'claimed_at', 'TEXT');
  addColumnIfMissing(db, 'tickets', 'last_activity_at', 'TEXT');
  addColumnIfMissing(db, 'tickets', 'close_warning_sent_at', 'TEXT');

  const hasTicketNumber = db
    .prepare("SELECT COUNT(*) as cnt FROM pragma_table_info('tickets') WHERE name = 'ticket_number'")
    .get() as { cnt: number };

  if (hasTicketNumber.cnt === 1) {
    const needsBackfill = (
      db.prepare('SELECT COUNT(*) as cnt FROM tickets WHERE ticket_number IS NULL').get() as { cnt: number }
    ).cnt;
    if (needsBackfill > 0) {
      const rows = db.prepare('SELECT thread_ts FROM tickets ORDER BY created_at ASC').all() as { thread_ts: string }[];
      let num = 1;
      const update = db.prepare('UPDATE tickets SET ticket_number = ? WHERE thread_ts = ?');
      const tx = db.transaction(() => {
        for (const row of rows) {
          update.run(num++, row.thread_ts);
        }
      });
      tx();
    }
  }
}
