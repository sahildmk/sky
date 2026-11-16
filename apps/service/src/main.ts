import { mkdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { defaultServicePort } from '@sky/api'
import { openDatabase } from './database'
import { startServer } from './server'
import { ThreadStore } from './thread-store'

const databasePath =
  process.env.SKY_DB_PATH ??
  join(homedir(), 'Library', 'Application Support', 'Sky', 'sky.sqlite')
const port = Number(process.env.SKY_PORT ?? defaultServicePort)

mkdirSync(dirname(databasePath), { recursive: true })
const server = startServer({
  store: new ThreadStore(openDatabase(databasePath)),
  port,
})
console.log(
  `Sky service listening on ${server.url}, database at ${databasePath}`,
)
