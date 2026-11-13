# Sky MCP server

Gives an agent tools to keep threads in Sky: `list_threads`, `get_thread`, `create_thread`, `add_message`, `update_thread`, `resolve_thread` and `reopen_thread`. It runs over stdio and calls the [Sky service](../service/README.md), which must be running.

## Register it

For ChatGPT and Codex, add this to `~/.codex/config.toml`, with your own paths:

```toml
[mcp_servers.sky]
command = "/Users/you/.bun/bin/bun"
args = ["/Users/you/sky/apps/mcp/src/main.ts"]
```

Set `SKY_SERVICE_URL` in the server's environment if the service is not on `http://127.0.0.1:4747`.

The server's instructions tell the agent to record a topic's conclusion and a link back to the original message rather than every message, and to add to an open thread on the same topic instead of starting another.
