import { z } from 'zod'
import {
  errorResponseSchema,
  messageSchema,
  threadSchema,
  threadWithMessagesSchema,
  type AddMessageInput,
  type CreateThreadInput,
  type ThreadStatus,
  type UpdateThreadInput,
} from './schemas'

export const defaultServicePort = 4747
export const defaultServiceUrl = `http://127.0.0.1:${defaultServicePort}`

/** A request the service refused, or a service that could not be reached (`status` is undefined). */
export class SkyServiceError extends Error {
  constructor(
    message: string,
    readonly status?: number,
    options?: ErrorOptions,
  ) {
    super(message, options)
    this.name = 'SkyServiceError'
  }
}

/** Calls the Sky service's HTTP API and validates what comes back. */
export function createSkyClient(baseUrl: string = defaultServiceUrl) {
  async function request<T>(
    schema: z.ZodType<T>,
    path: string,
    method = 'GET',
    body?: unknown,
  ): Promise<T> {
    let response: Response
    try {
      response = await fetch(new URL(path, baseUrl), {
        method,
        headers:
          body === undefined
            ? undefined
            : { 'content-type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
      })
    } catch (cause) {
      throw new SkyServiceError(
        `The Sky service is not reachable at ${baseUrl}.`,
        undefined,
        {
          cause,
        },
      )
    }
    const payload: unknown = await response.json().catch(() => null)
    if (!response.ok) {
      const error = errorResponseSchema.safeParse(payload)
      throw new SkyServiceError(
        error.success ? error.data.error : `HTTP ${response.status}`,
        response.status,
      )
    }
    return schema.parse(payload)
  }

  const threadPath = (id: string) => `/threads/${encodeURIComponent(id)}`

  return {
    listThreads: (status: ThreadStatus = 'open') =>
      request(z.array(threadSchema), `/threads?status=${status}`),
    getThread: (id: string) =>
      request(threadWithMessagesSchema, threadPath(id)),
    createThread: (input: CreateThreadInput) =>
      request(threadWithMessagesSchema, '/threads', 'POST', input),
    addMessage: (threadId: string, input: AddMessageInput) =>
      request(messageSchema, `${threadPath(threadId)}/messages`, 'POST', input),
    updateThread: (id: string, input: UpdateThreadInput) =>
      request(threadSchema, threadPath(id), 'PATCH', input),
  }
}

export type SkyClient = ReturnType<typeof createSkyClient>
