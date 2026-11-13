import type { Database } from 'bun:sqlite'
import type {
  AddMessageInput,
  CreateThreadInput,
  Message,
  Thread,
  ThreadStatus,
  ThreadWithMessages,
  UpdateThreadInput,
} from '@sky/api'

type ThreadRow = {
  id: string
  title: string
  summary: string
  created_at: string
  updated_at: string
  resolved_at: string | null
}

type MessageRow = {
  id: string
  thread_id: string
  created_at: string
  body: string
}

const toThread = (row: ThreadRow): Thread => ({
  id: row.id,
  title: row.title,
  summary: row.summary,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
  resolvedAt: row.resolved_at,
})

const toMessage = (row: MessageRow): Message => ({
  id: row.id,
  threadId: row.thread_id,
  createdAt: row.created_at,
  body: row.body,
})

const statusFilter: Record<ThreadStatus, string> = {
  open: 'WHERE resolved_at IS NULL',
  resolved: 'WHERE resolved_at IS NOT NULL',
  all: '',
}

/** Reads and writes threads and their messages. Methods taking an id return null when no such thread exists. */
export class ThreadStore {
  constructor(
    private readonly db: Database,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** Threads with the most recent activity first. */
  list(status: ThreadStatus): Thread[] {
    return this.db
      .query<ThreadRow, []>(
        `SELECT * FROM thread ${statusFilter[status]} ORDER BY updated_at DESC, id DESC`,
      )
      .all()
      .map(toThread)
  }

  get(id: string): ThreadWithMessages | null {
    const row = this.db
      .query<ThreadRow, [string]>('SELECT * FROM thread WHERE id = ?')
      .get(id)
    if (!row) return null
    const messages = this.db
      .query<MessageRow, [string]>(
        'SELECT * FROM message WHERE thread_id = ? ORDER BY created_at, id',
      )
      .all(id)
      .map(toMessage)
    return { ...toThread(row), messages }
  }

  create(input: CreateThreadInput): ThreadWithMessages {
    const id = Bun.randomUUIDv7()
    const now = this.timestamp()
    this.db.transaction(() => {
      this.db
        .query(
          `INSERT INTO thread (id, title, summary, created_at, updated_at)
           VALUES ($id, $title, $summary, $now, $now)`,
        )
        .run({ id, title: input.title, summary: input.summary, now })
      if (input.body !== undefined) this.insertMessage(id, input.body, now)
    })()
    return this.get(id)!
  }

  addMessage(threadId: string, input: AddMessageInput): Message | null {
    const now = this.timestamp()
    return this.db.transaction(() => {
      const touched = this.db
        .query('UPDATE thread SET updated_at = $now WHERE id = $threadId')
        .run({ threadId, now })
      if (touched.changes === 0) return null
      return this.insertMessage(threadId, input.body, now)
    })()
  }

  update(id: string, input: UpdateThreadInput): Thread | null {
    const now = this.timestamp()
    const resolvedAt =
      input.resolved === undefined
        ? 'resolved_at'
        : input.resolved
          ? 'coalesce(resolved_at, $now)' // resolving twice keeps the first time
          : 'NULL'
    const row = this.db
      .query<ThreadRow, Record<string, string | null>>(
        `UPDATE thread SET
           title = coalesce($title, title),
           summary = coalesce($summary, summary),
           resolved_at = ${resolvedAt},
           updated_at = $now
         WHERE id = $id
         RETURNING *`,
      )
      .get({
        id,
        now,
        title: input.title ?? null,
        summary: input.summary ?? null,
      })
    return row ? toThread(row) : null
  }

  private insertMessage(
    threadId: string,
    body: string,
    createdAt: string,
  ): Message {
    const row = this.db
      .query<MessageRow, Record<string, string>>(
        `INSERT INTO message (id, thread_id, created_at, body)
         VALUES ($id, $threadId, $createdAt, $body)
         RETURNING *`,
      )
      .get({ id: Bun.randomUUIDv7(), threadId, createdAt, body })
    return toMessage(row!)
  }

  private timestamp(): string {
    return this.now().toISOString()
  }
}
