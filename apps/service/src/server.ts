import {
  addMessageInputSchema,
  createThreadInputSchema,
  threadStatusSchema,
  updateThreadInputSchema,
} from '@sky/api'
import { z } from 'zod'
import type { ThreadStore } from './thread-store'

/** Thrown from a route to answer with `status` and `{ error: message }`. */
class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message)
  }
}

function parse<T>(schema: z.ZodType<T>, value: unknown): T {
  const result = schema.safeParse(value)
  if (!result.success) throw new HttpError(400, z.prettifyError(result.error))
  return result.data
}

async function readJson(request: Request): Promise<unknown> {
  try {
    return await request.json()
  } catch {
    throw new HttpError(400, 'The request body is not valid JSON.')
  }
}

function found<T>(value: T | null, id: string): T {
  if (value === null) throw new HttpError(404, `No thread with id ${id}.`)
  return value
}

/** Serves the threads API on `hostname:port`. Port 0 picks a free port. */
export function startServer(options: {
  store: ThreadStore
  port: number
  hostname?: string
}) {
  const { store } = options
  return Bun.serve({
    hostname: options.hostname ?? '127.0.0.1',
    port: options.port,
    routes: {
      '/health': { GET: () => Response.json({ ok: true }) },
      '/threads': {
        GET: (request) => {
          const status =
            new URL(request.url).searchParams.get('status') ?? 'open'
          return Response.json(store.list(parse(threadStatusSchema, status)))
        },
        POST: async (request) => {
          const input = parse(createThreadInputSchema, await readJson(request))
          return Response.json(store.create(input), { status: 201 })
        },
      },
      '/threads/:id': {
        GET: (request) =>
          Response.json(found(store.get(request.params.id), request.params.id)),
        PATCH: async (request) => {
          const input = parse(updateThreadInputSchema, await readJson(request))
          return Response.json(
            found(store.update(request.params.id, input), request.params.id),
          )
        },
      },
      '/threads/:id/messages': {
        POST: async (request) => {
          const input = parse(addMessageInputSchema, await readJson(request))
          const message = found(
            store.addMessage(request.params.id, input),
            request.params.id,
          )
          return Response.json(message, { status: 201 })
        },
      },
    },
    fetch: () => Response.json({ error: 'Not found.' }, { status: 404 }),
    error: (error) => {
      if (error instanceof HttpError) {
        return Response.json({ error: error.message }, { status: error.status })
      }
      console.error(error)
      return Response.json({ error: 'Internal error.' }, { status: 500 })
    },
  })
}
