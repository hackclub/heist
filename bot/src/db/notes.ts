import { getDb } from './database';

export interface InternalNote {
  id: number;
  thread_ts: string;
  author_id: string;
  author_name: string;
  note: string;
  created_at: string;
}

export function addNote(
  threadTs: string,
  authorId: string,
  authorName: string,
  note: string,
): void {
  const db = getDb();
  const now = new Date().toISOString();
  db.prepare(
    'INSERT INTO internal_notes (thread_ts, author_id, author_name, note, created_at) VALUES (?, ?, ?, ?, ?)',
  ).run(threadTs, authorId, authorName, note, now);
}

export function getNotes(threadTs: string): InternalNote[] {
  const db = getDb();
  return db
    .prepare('SELECT * FROM internal_notes WHERE thread_ts = ? ORDER BY id ASC')
    .all(threadTs) as InternalNote[];
}
