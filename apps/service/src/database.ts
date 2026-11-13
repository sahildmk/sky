import { Database } from 'bun:sqlite'

/**
 * Schema changes, applied in order. The database's `user_version` records how
 * many have been applied, so a migration is never edited once it has shipped:
 * add a new one to the end instead.
 */
const migrations: string[] = [
  `
  CREATE TABLE thread (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    resolved_at TEXT
  );
  CREATE TABLE message (
    id TEXT PRIMARY KEY,
    thread_id TEXT NOT NULL REFERENCES thread (id) ON DELETE CASCADE,
    created_at TEXT NOT NULL,
    body TEXT NOT NULL
  );
  CREATE INDEX message_by_thread ON message (thread_id, created_at);
  `,
]

/** Opens (creating if needed) the database at `path` and brings its schema up to date. */
export function openDatabase(path: string): Database {
  const db = new Database(path, { create: true, strict: true })
  db.exec('PRAGMA journal_mode = WAL')
  db.exec('PRAGMA foreign_keys = ON')
  db.exec('PRAGMA busy_timeout = 5000')
  migrate(db)
  return db
}

function migrate(db: Database) {
  const { user_version: applied } = db.query('PRAGMA user_version').get() as {
    user_version: number
  }
  if (applied > migrations.length) {
    throw new Error(
      `The database is at schema version ${applied}, newer than this service's ${migrations.length}.`,
    )
  }
  db.transaction(() => {
    for (const sql of migrations.slice(applied)) db.exec(sql)
    db.exec(`PRAGMA user_version = ${migrations.length}`)
  })()
}
