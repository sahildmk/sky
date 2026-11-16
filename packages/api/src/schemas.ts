import { z } from 'zod'

/** A topic tracked on Sky: a title, a short summary for its card, and whether it is still open. */
export const threadSchema = z.object({
  id: z.string(),
  title: z.string(),
  summary: z.string(),
  createdAt: z.iso.datetime(),
  /** When the thread was created, last given a message, or last edited. */
  updatedAt: z.iso.datetime(),
  /** Null while the thread is open. */
  resolvedAt: z.iso.datetime().nullable(),
})
export type Thread = z.infer<typeof threadSchema>

/** One entry in a thread. The body is markdown: links and images use markdown syntax. */
export const messageSchema = z.object({
  id: z.string(),
  threadId: z.string(),
  createdAt: z.iso.datetime(),
  body: z.string(),
})
export type Message = z.infer<typeof messageSchema>

/** A thread with its messages, oldest first. */
export const threadWithMessagesSchema = threadSchema.extend({
  messages: z.array(messageSchema),
})
export type ThreadWithMessages = z.infer<typeof threadWithMessagesSchema>

export const threadStatusSchema = z.enum(['open', 'resolved', 'all'])
export type ThreadStatus = z.infer<typeof threadStatusSchema>

export const createThreadInputSchema = z.object({
  title: z
    .string()
    .trim()
    .min(1)
    .describe('A short title for the thread card.'),
  summary: z
    .string()
    .describe(
      'Markdown summary shown on the thread card. Keep it to a few lines.',
    ),
  body: z
    .string()
    .min(1)
    .optional()
    .describe(
      'Markdown for the first message, such as a link to the original conversation.',
    ),
})
export type CreateThreadInput = z.infer<typeof createThreadInputSchema>

export const addMessageInputSchema = z.object({
  body: z.string().min(1).describe('Markdown body of the message.'),
})
export type AddMessageInput = z.infer<typeof addMessageInputSchema>

export const updateThreadInputSchema = z
  .object({
    title: z.string().trim().min(1).optional(),
    summary: z.string().optional(),
    resolved: z.boolean().optional(),
  })
  .refine(
    (input) => Object.values(input).some((value) => value !== undefined),
    {
      message: 'Provide at least one of title, summary or resolved.',
    },
  )
export type UpdateThreadInput = z.infer<typeof updateThreadInputSchema>

/** The body of every non-2xx response from the service. */
export const errorResponseSchema = z.object({ error: z.string() })
