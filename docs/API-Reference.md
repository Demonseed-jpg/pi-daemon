# API Reference

## Base URL

```
http://localhost:4200
```

## Authentication

When `api_key` is configured, include one of:
- `Authorization: Bearer <api_key>`
- `X-API-Key: <api_key>`

Unauthenticated endpoints: `GET /`, `GET /api/health`

---

## REST Endpoints

### System

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check — returns `{"status": "ok"}` |
| `GET` | `/api/status` | Daemon status: version, uptime, agent count |

### Agents

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/agents` | List all registered agents |
| `POST` | `/api/agents` | Register a new agent |
| `GET` | `/api/agents/:id` | Get agent details |
| `DELETE` | `/api/agents/:id` | Unregister an agent |
| `POST` | `/api/agents/:id/heartbeat` | Record agent heartbeat |

#### POST /api/agents

```json
{
  "name": "my-agent",
  "kind": "api_client",
  "model": "claude-sonnet-4-20250514"
}
```

Agent kinds: `pi_instance`, `web_chat`, `terminal_chat`, `api_client`, `hand`

### Sessions (Phase 2+)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/sessions` | List sessions (`?agent_id=...&limit=50`) |
| `GET` | `/api/sessions/:id` | Get session details |
| `GET` | `/api/sessions/:id/messages` | Get messages (`?limit=100&offset=0`) |

### Usage (Phase 2+)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/usage/today` | Today's cost + token breakdown |
| `GET` | `/api/usage/daily` | Daily usage (`?days=7`) |
| `GET` | `/api/usage/by-agent` | Usage grouped by agent (30d) |
| `GET` | `/api/usage/by-model` | Usage grouped by model (30d) |

### Scheduler (Phase 3+)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/scheduler/jobs` | List all cron jobs |
| `POST` | `/api/scheduler/jobs` | Create a cron job |
| `DELETE` | `/api/scheduler/jobs/:id` | Remove a job |
| `PATCH` | `/api/scheduler/jobs/:id` | Enable/disable a job |

### Hands (Phase 4+)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/hands` | List available Hands |
| `GET` | `/api/hands/instances` | List active instances |
| `POST` | `/api/hands/:name/activate` | Activate a Hand |
| `POST` | `/api/hands/:id/deactivate` | Deactivate |
| `POST` | `/api/hands/:id/pause` | Pause |
| `POST` | `/api/hands/:id/resume` | Resume |

### Approvals (Phase 4+)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/approvals` | List pending approvals |
| `GET` | `/api/approvals/count` | Pending count |
| `POST` | `/api/approvals/:id/approve` | Approve a request |
| `POST` | `/api/approvals/:id/reject` | Reject a request |

### Events

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/events` | Recent event history (last 100) |

---

## WebSocket

### Connection

```
ws://localhost:4200/ws/:agent_id
ws://localhost:4200/ws/:agent_id?api_key=xxx  (when auth enabled)
```

### Client → Server

```json
{"type": "message", "content": "Hello!"}
{"type": "set_model", "model": "claude-sonnet-4-20250514"}
{"type": "ping"}
```

### Server → Client

```json
{"type": "typing", "state": "start"}
{"type": "typing", "state": "tool", "tool_name": "bash"}
{"type": "typing", "state": "stop"}
{"type": "text_delta", "content": "Here's how..."}
{"type": "response", "content": "Full text", "input_tokens": 150, "output_tokens": 320}
{"type": "error", "content": "Rate limited"}
{"type": "agents_updated", "agents": [...]}
{"type": "pong"}
```

---

## OpenAI-Compatible API

### POST /v1/chat/completions

Any OpenAI-compatible client works. The `model` field maps to an agent name or ID.

```bash
curl http://localhost:4200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "pi-main",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }'
```

**Streaming** (`"stream": true`): Returns Server-Sent Events matching the OpenAI SSE format. Each chunk is `data: {...}\n\n`, ending with `data: [DONE]\n\n`.

**Python example:**
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:4200/v1", api_key="your-key")
response = client.chat.completions.create(
    model="pi-main",
    messages=[{"role": "user", "content": "Hello"}]
)
print(response.choices[0].message.content)
```
