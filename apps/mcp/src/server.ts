import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js'
import {
  addMessageInputSchema,
  createThreadInputSchema,
  threadStatusSchema,
  type SkyClient,
} from '@sky/api'
import { z } from 'zod'

const instructions = `Sky shows threads as cards on the user's Mac, so they can find a topic again without scrolling back through a long conversation.

Use it to keep a record of each topic, not a copy of every message. When a topic reaches a conclusion worth keeping, create a thread with a short title, a summary, and a first message linking to the original message. Add a message when the topic moves on. Resolve the thread when the topic is finished.

Before creating a thread, list the open threads and add to an existing one if it covers the same topic.

Summaries and message bodies are markdown. Write links as [text](url) and images as ![alt](url-or-absolute-file-path).`

const threadId = z
  .string()
  .describe(
    'The id of the thread, as returned by create_thread or list_threads.',
  )

function json(value: unknown): CallToolResult {
  return { content: [{ type: 'text', text: JSON.stringify(value, null, 2) }] }
}

/** An MCP server whose tools read and write threads through the Sky service. */
export function createMcpServer(client: SkyClient): McpServer {
  const server = new McpServer(
    { name: 'sky', version: '0.1.0' },
    { instructions },
  )

  server.registerTool(
    'list_threads',
    {
      title: 'List threads',
      description:
        'Lists threads, most recently active first. Messages are not included.',
      inputSchema: { status: threadStatusSchema.default('open') },
      annotations: { readOnlyHint: true },
    },
    async ({ status }) => json(await client.listThreads(status)),
  )

  server.registerTool(
    'get_thread',
    {
      title: 'Get thread',
      description: 'Gets a thread with all of its messages, oldest first.',
      inputSchema: { threadId },
      annotations: { readOnlyHint: true },
    },
    async ({ threadId }) => json(await client.getThread(threadId)),
  )

  server.registerTool(
    'create_thread',
    {
      title: 'Create thread',
      description: 'Creates an open thread, optionally with a first message.',
      inputSchema: createThreadInputSchema.shape,
    },
    async (input) => json(await client.createThread(input)),
  )

  server.registerTool(
    'add_message',
    {
      title: 'Add message',
      description: 'Adds a markdown message to the end of a thread.',
      inputSchema: { threadId, ...addMessageInputSchema.shape },
    },
    async ({ threadId, body }) =>
      json(await client.addMessage(threadId, { body })),
  )

  server.registerTool(
    'update_thread',
    {
      title: 'Update thread',
      description: "Replaces a thread's title, summary, or both.",
      inputSchema: {
        threadId,
        title: z.string().trim().min(1).optional(),
        summary: z
          .string()
          .optional()
          .describe('Markdown summary shown on the thread card.'),
      },
    },
    async ({ threadId, title, summary }) =>
      json(await client.updateThread(threadId, { title, summary })),
  )

  server.registerTool(
    'resolve_thread',
    {
      title: 'Resolve thread',
      description:
        'Marks a thread as finished. It stays in Sky and can be reopened.',
      inputSchema: { threadId },
      annotations: { idempotentHint: true },
    },
    async ({ threadId }) =>
      json(await client.updateThread(threadId, { resolved: true })),
  )

  server.registerTool(
    'reopen_thread',
    {
      title: 'Reopen thread',
      description: 'Marks a resolved thread as open again.',
      inputSchema: { threadId },
      annotations: { idempotentHint: true },
    },
    async ({ threadId }) =>
      json(await client.updateThread(threadId, { resolved: false })),
  )

  return server
}
