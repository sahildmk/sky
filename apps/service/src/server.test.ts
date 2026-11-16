import { afterEach, beforeEach, describe, expect, test } from 'bun:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createSkyClient, SkyServiceError, type SkyClient } from '@sky/api'
import { openDatabase } from './database'
import { startServer } from './server'
import { ThreadStore } from './thread-store'

let directory: string
let server: ReturnType<typeof startServer>
let client: SkyClient
let clock: number

beforeEach(() => {
  directory = mkdtempSync(join(tmpdir(), 'sky-service-'))
  clock = Date.parse('2026-11-11T09:00:00.000Z')
  // Each write moves the clock on a second, so activity order is unambiguous.
  const store = new ThreadStore(
    openDatabase(join(directory, 'sky.sqlite')),
    () => {
      clock += 1000
      return new Date(clock)
    },
  )
  server = startServer({ store, port: 0 })
  client = createSkyClient(server.url.href)
})

afterEach(async () => {
  await server.stop(true)
  rmSync(directory, { recursive: true, force: true })
})

async function rejection(promise: Promise<unknown>): Promise<SkyServiceError> {
  const error = await promise.then(
    () => null,
    (error: unknown) => error,
  )
  expect(error).toBeInstanceOf(SkyServiceError)
  return error as SkyServiceError
}

describe('threads', () => {
  test('a new thread is open and carries its first message', async () => {
    const thread = await client.createThread({
      title: 'Koho check-in',
      summary: 'Moved to Thursday.',
      body: '[Original message](https://example.slack.com/archives/D1/p1)',
    })

    expect(thread).toMatchObject({
      title: 'Koho check-in',
      summary: 'Moved to Thursday.',
      resolvedAt: null,
      createdAt: '2026-11-11T09:00:01.000Z',
      updatedAt: '2026-11-11T09:00:01.000Z',
    })
    expect(thread.messages.map((message) => message.body)).toEqual([
      '[Original message](https://example.slack.com/archives/D1/p1)',
    ])
    expect(await client.getThread(thread.id)).toEqual(thread)
  })

  test('messages come back oldest first and move the thread to the top of the list', async () => {
    const first = await client.createThread({ title: 'First', summary: '' })
    const second = await client.createThread({ title: 'Second', summary: '' })
    expect((await client.listThreads()).map((thread) => thread.title)).toEqual([
      'Second',
      'First',
    ])

    await client.addMessage(first.id, { body: 'one' })
    await client.addMessage(first.id, { body: '![chart](/tmp/chart.png)' })

    const fetched = await client.getThread(first.id)
    expect(fetched.messages.map((message) => message.body)).toEqual([
      'one',
      '![chart](/tmp/chart.png)',
    ])
    expect(fetched.updatedAt > second.updatedAt).toBe(true)
    expect((await client.listThreads()).map((thread) => thread.title)).toEqual([
      'First',
      'Second',
    ])
  })

  test('resolving hides a thread from the open list until it is reopened', async () => {
    const thread = await client.createThread({
      title: 'Done soon',
      summary: '',
    })

    const resolved = await client.updateThread(thread.id, { resolved: true })
    expect(resolved.resolvedAt).not.toBeNull()
    expect(await client.listThreads('open')).toEqual([])
    expect((await client.listThreads('resolved')).map((t) => t.id)).toEqual([
      thread.id,
    ])

    const resolvedAgain = await client.updateThread(thread.id, {
      resolved: true,
    })
    expect(resolvedAgain.resolvedAt).toBe(resolved.resolvedAt)

    const reopened = await client.updateThread(thread.id, { resolved: false })
    expect(reopened.resolvedAt).toBeNull()
    expect((await client.listThreads('open')).map((t) => t.id)).toEqual([
      thread.id,
    ])
  })

  test('an update changes only the fields it names', async () => {
    const thread = await client.createThread({
      title: 'Old title',
      summary: 'Old summary',
    })

    const updated = await client.updateThread(thread.id, {
      summary: 'New summary',
    })

    expect(updated).toMatchObject({
      title: 'Old title',
      summary: 'New summary',
      resolvedAt: null,
    })
  })

  test('an unknown thread id is a 404', async () => {
    expect((await rejection(client.getThread('missing'))).status).toBe(404)
    expect(
      (await rejection(client.addMessage('missing', { body: 'x' }))).status,
    ).toBe(404)
    expect(
      (await rejection(client.updateThread('missing', { title: 'x' }))).status,
    ).toBe(404)
  })

  test('invalid input is a 400 that says what is wrong', async () => {
    const blankTitle = await rejection(
      client.createThread({ title: '  ', summary: '' }),
    )
    expect(blankTitle.status).toBe(400)
    expect(blankTitle.message).toContain('title')

    const thread = await client.createThread({ title: 'Thread', summary: '' })
    const emptyUpdate = await rejection(client.updateThread(thread.id, {}))
    expect(emptyUpdate.status).toBe(400)

    const badStatus = await fetch(new URL('/threads?status=closed', server.url))
    expect(badStatus.status).toBe(400)
  })
})

describe('database', () => {
  test('threads survive reopening the database', async () => {
    const thread = await client.createThread({ title: 'Kept', summary: '' })
    await server.stop(true)

    const reopened = new ThreadStore(
      openDatabase(join(directory, 'sky.sqlite')),
    )

    expect(reopened.get(thread.id)?.title).toBe('Kept')
  })

  test('a database from a newer schema is refused rather than written to', () => {
    const path = join(directory, 'newer.sqlite')
    openDatabase(path).exec('PRAGMA user_version = 99')

    expect(() => openDatabase(path)).toThrow('schema version 99')
  })
})
