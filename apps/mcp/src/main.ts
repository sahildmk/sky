import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { createSkyClient } from '@sky/api'
import { createMcpServer } from './server'

const server = createMcpServer(createSkyClient(process.env.SKY_SERVICE_URL))
await server.connect(new StdioServerTransport())
