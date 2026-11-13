# Sky service

Stores threads and their messages in SQLite and serves them over HTTP on `127.0.0.1:4747`. The MCP server and the Mac app are both clients of it.

## Run it

```sh
bun run start            # in this directory
bun run install-agent    # run it at login and restart it if it exits
bun run uninstall-agent  # stop it and remove the launch agent; the database stays
```

The launch agent runs the service from this checkout. Its log is `~/Library/Logs/Sky/service.log`.

| Variable      | Default                                        |
| ------------- | ---------------------------------------------- |
| `SKY_PORT`    | `4747`                                         |
| `SKY_DB_PATH` | `~/Library/Application Support/Sky/sky.sqlite` |

## API

Request and response bodies are JSON, validated by the schemas in `packages/api`. Errors come back as `{ "error": "…" }` with a 4xx status. Timestamps are ISO 8601 in UTC.

| Request                      | Body                              | Returns                                                                                 |
| ---------------------------- | --------------------------------- | --------------------------------------------------------------------------------------- |
| `GET /threads?status=open`   |                                   | Threads, most recently active first. `status` is `open` (default), `resolved` or `all`. |
| `POST /threads`              | `title`, `summary`, `body?`       | The new thread with its messages. `body` becomes the first message.                     |
| `GET /threads/:id`           |                                   | The thread with its messages, oldest first.                                             |
| `PATCH /threads/:id`         | `title?`, `summary?`, `resolved?` | The updated thread.                                                                     |
| `POST /threads/:id/messages` | `body`                            | The new message.                                                                        |
| `GET /health`                |                                   | `{ "ok": true }`                                                                        |

Summaries and message bodies are markdown. Adding a message, editing a thread, or resolving it moves its `updatedAt` forward. Resolving a thread that is already resolved keeps its original `resolvedAt`.

## Schema changes

`src/database.ts` holds the migrations in order, and the database's `user_version` records how many have run. Add a new migration to the end of the list rather than editing one that has shipped. The service refuses to open a database whose `user_version` is newer than it knows.
