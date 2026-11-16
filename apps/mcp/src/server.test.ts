import { afterEach, beforeEach, expect, test } from 'bun:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js'
import {
  createSkyClient,
  threadSchema,
  threadWithMessagesSchema,
  type SkyClient,
} from '@sky/api'
import { openDatabase, startServer, ThreadStore } from '@sky/service'
import { z } from 'zod'
import { createMcpServer } from './server'

let directory: string
let service: ReturnType<typeof startServer>
let sky: SkyClient
let mcp: Client

async function connect(skyClient: SkyClient): Promise<Client> {
  const [clientTransport, serverTransport] =
    InMemoryTransport.createLinkedPair()
  await createMcpServer(skyClient).connect(serverTransport)
  const client = new Client({ name: 'test', version: '0.0.0' })
  await client.connect(clientTransport)
  return client
}

beforeEach(async () => {
  directory = mkdtempSync(join(tmpdir(), 'sky-mcp-'))
  service = startServer({
    store: new ThreadStore(openDatabase(join(directory, 'sky.sqlite'))),
    port: 0,
  })
  sky = createSkyClient(service.url.href)
  mcp = await connect(sky)
})

afterEach(async () => {
  await mcp.close()
  await service.stop(true)
  rmSync(directory, { recursive: true, force: true })
})

/** Calls a tool and parses the JSON it returns. */
async function call<T>(
  schema: z.ZodType<T>,
  name: string,
  args: Record<string, unknown>,
) {
  const result = await mcp.callTool({ name, arguments: args })
  expect(result.isError).toBeFalsy()
  const [content] = result.content as { type: string; text: string }[]
  return schema.parse(JSON.parse(content!.text))
}

test('the tools create, extend and resolve a thread in the service', async () => {
  const created = await call(threadWithMessagesSchema, 'create_thread', {
    title: 'Factory investigation',
    summary: 'Found the stuck run.',
    body: '[Original message](https://example.slack.com/archives/D1/p2)',
  })
  await call(z.unknown(), 'add_message', {
    threadId: created.id,
    body: 'Fixed in **#123**.',
  })
  await call(z.unknown(), 'update_thread', {
    threadId: created.id,
    summary: 'Fixed.',
  })
  await call(threadSchema, 'resolve_thread', { threadId: created.id })

  const stored = await sky.getThread(created.id)
  expect(stored.summary).toBe('Fixed.')
  expect(stored.resolvedAt).not.toBeNull()
  expect(stored.messages.map((message) => message.body)).toEqual([
    '[Original message](https://example.slack.com/archives/D1/p2)',
    'Fixed in **#123**.',
  ])
  expect(await call(z.array(threadSchema), 'list_threads', {})).toEqual([])
  expect(
    (
      await call(z.array(threadSchema), 'list_threads', { status: 'resolved' })
    ).map((t) => t.id),
  ).toEqual([created.id])

  await call(threadSchema, 'reopen_thread', { threadId: created.id })
  expect((await sky.listThreads('open')).map((t) => t.id)).toEqual([created.id])
})

test('a service error comes back to the caller as a tool error', async () => {
  const result = await mcp.callTool({
    name: 'get_thread',
    arguments: { threadId: 'missing' },
  })

  expect(result.isError).toBe(true)
  expect(JSON.stringify(result.content)).toContain('No thread with id missing')
})

test('an unreachable service is reported as such', async () => {
  const unreachable = await connect(createSkyClient('http://127.0.0.1:9'))

  const result = await unreachable.callTool({
    name: 'list_threads',
    arguments: {},
  })

  expect(result.isError).toBe(true)
  expect(JSON.stringify(result.content)).toContain('not reachable')
  await unreachable.close()
})
