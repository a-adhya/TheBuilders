# LLMTools + Weather Integration Plan

This document outlines how to use the LLMTools code (chatterd + sample Swift client) in our existing iOS app and Python backend, with clear options for adding weather context via either simple prompt enrichment or structured tool-calling.

---

## Goals

- Integrate LLMTools ("chatterd") as a pluggable chat backend option alongside the current Anthropic path.
- Make weather-aware fashion advice reliable and easy to evolve.
- Keep the iOS API contract stable; optionally add a streaming path for richer sessions.

---

## Current State (What we have)

- iOS `ChatServiceAPI.swift` posts to `POST /chat` with messages shaped like `{ role: "user"|"assistant", content: string }` and already appends a weather paragraph to the last user message when available.
- Backend `src/api/server.py` exposes `POST /chat` and delegates to `services/chat_service.py`, which currently calls Anthropic directly.
- LLMTools code:
  - `LLMtools code/chatterd/main.py` and `handlers.py` exposing:
    - `POST /llmprompt` → forwards to Ollama's `/generate` (NDJSON stream; no tools).
    - `POST /llmtools` → bridges to Ollama's `/chat` with tool-calling; returns SSE events (tokens, tool_calls, errors).
    - `GET /weather` → returns weather JSON given `{ lat, lon }`.
  - Sample Swift client toolbox includes a `get_location` tool (for client-side tool-calling proof-of-concept).

---

## Recommended Architecture

- Baseline (simple, reliable):
  - iOS → FastAPI (`/chat`) → backend selects a chat backend (Anthropic or LLMTools non-tools).
  - Weather is appended to the user message on iOS.
- Advanced (richer, structured):
  - iOS → FastAPI (`/chat/tools`) → chatterd `/llmtools` (SSE) with server-side weather tool.
  - Optional client tool for location (if you want device-provided location at inference time).
- Hybrid: Keep baseline as default, add the advanced SSE route as an opt-in.

---

## Interfaces and Contracts

### iOS → Backend (existing, keep stable)

- Endpoint: `POST /chat`
- Body:
  ```json
  {
    "messages": [
      { "role": "user", "content": "..." },
      { "role": "assistant", "content": "..." }
    ]
  }
  ```
- Response:
  ```json
  { "response": "..." }
  ```
- Validation: roles in {"user","assistant"}, non-empty list.

### Backend → LLM backend (new pluggable abstraction)

- Introduce `ChatBackend` interface:
  - `generate_response(messages: list[dict]) -> str`
- Implementations:
  - `AnthropicBackend`
  - `LLMToolsBackend` (parity, non-streaming) → calls chatterd `/llmprompt`, collects NDJSON to a string.
  - `LLMToolsToolsBackend` (advanced, streaming SSE) → proxies iOS to `/llmtools` for tool-calling.
- Env flags:
  - `CHAT_BACKEND=anthropic|llmtools|llmtools-tools`
  - `CHATTERD_URL=http://chatterd:8080` (Docker) or `http://127.0.0.1:5100` (local)

### chatterd routes (from LLMTools code)

- `POST /llmprompt` → NDJSON stream from Ollama `/generate`.
- `POST /llmtools` → SSE stream for tool-calling via Ollama `/chat` + server TOOLBOX.
- `GET /weather` → `{ lat, lon }` → weather JSON via `toolbox.getWeather`.

Note: `handlers.py` references a DB pool (`main.server.pool`); if not configured, you can run statelessly by passing full history from the API each turn to `/llmtools`.

---

## Weather Integration Strategies

1) Baseline (prompt enrichment; already in iOS)
   - Fetch weather on device and append to the last user message in a consistent template:
     - Start with a clear delimiter (e.g., "this is my current weather context:")
     - Include: condition, temp, feels-like, high/low, wind, humidity
   - Pros: simple, reliable, no streaming or tool complexity.
   - Cons: less structured; weather can get stale across turns.

2) Tool-calling (server-side via chatterd)
   - Use `/chat/tools` from iOS to get an SSE stream.
   - Backend constructs an `OllamaRequest` and posts to chatterd `/llmtools`.
   - Model calls server toolbox for weather when needed; you can omit client tools entirely.
   - Optional: expose a client tool like `get_location` if you want device-provided coordinates on demand.
   - Pros: structured, fresh data, better multi-turn accumulation (by appID).
   - Cons: adds streaming + chatterd dependency and (optionally) a persistence layer for history.

3) Hybrid
   - Keep baseline default for most interactions; expose a toggle or auto-switch to tool-calling for certain prompts.

---

## Backend Work Plan

1) Refactor to pluggable backends
   - Create `src/services/chat_backend.py` with `ChatBackend` Protocol.
   - Move Anthropic logic into `AnthropicBackend`.
   - Implement `LLMToolsBackend` (non-streaming):
     - `POST {CHATTERD_URL}/llmprompt`
     - Accumulate NDJSON → string
     - Timeout ~15s; retry once on 5xx; map errors to `HTTPException(502/504)`
   - Wire selection in `api/server.py:get_chat_service()` based on `CHAT_BACKEND`.

2) Optional: streaming SSE route
   - Add `GET/POST /chat/tools` that proxies SSE to `{CHATTERD_URL}/llmtools`.
   - Input: same `messages` shape plus an `app_id` (UUID) for history, or pass full history each call.
   - Output: Server-Sent Events to iOS.

3) Policy and limits
   - Enforce allowed roles, max messages, and prompt-size trimming (drop oldest messages).
   - Rate limiting and request size limits on `/chat` and `/chat/tools`.

---

## iOS Work Plan

- Baseline path (keep as-is):
  - Continue appending weather context in `ChatServiceAPI.swift`.
  - Ensure `baseURL` is configurable per scheme (simulator: `http://127.0.0.1:8000`; device: `http://<LAN-IP>:8000`).

- Optional streaming path:
  - Add a second chat method that consumes SSE from `/chat/tools`.
  - Decide if you want client tools (e.g., `get_location`); if yes, send tool schemas on first message for an `app_id` and respond to tool calls; if not, rely on server weather tool only.

---

## Deployment (Docker and Local)

- Add to `docker-compose.yml`:
  - `ollama` service (port `11434`), optionally with GPU; preload model as needed.
  - `chatterd` service built from `LLMtools code/chatterd` (expose `5100:8080` locally or internal-only if API is containerized).
  - Inject env: `OLLAMA_URL=http://ollama:11434` if required by chatterd.
  - Mount certs/keys as secrets or dev bind mounts; do not commit secrets.
- Optionally containerize the API and link it to `chatterd` via service name DNS.
- Local dev without Docker: run Ollama, then chatterd via uvicorn, and the API via uvicorn.

---

## Security and Config

- Env config (`.env`, not committed):
  - `CHAT_BACKEND=anthropic|llmtools|llmtools-tools`
  - `CHATTERD_URL=http://127.0.0.1:5100`
  - `API_KEY=` (Anthropic) for fallback
  - Weather API keys (if server-side weather is introduced)
- CORS: restrict origins if exposing API publicly.
- Location privacy: prefer coarse location where possible if sent from client.

---

## Observability

- Structured logs with request IDs and durations for `/chat` and `/chat/tools`.
- Metrics counters: request counts, 2xx/4xx/5xx, timeouts, retries.
- For SSE: log stream start/close and tool events.

---

## Testing Strategy

- Python unit tests:
  - `LLMToolsBackend` with mocked `httpx` for NDJSON; assert happy path, timeouts, 5xx, malformed payloads.
- Python integration tests:
  - Bring up `ollama + chatterd + api`; POST `/chat` with and without weather block; assert non-empty responses.
  - SSE smoke for `/chat/tools` (optional): read first few events.
- iOS:
  - Keep `MockChatService` for UI.
  - Optional integration smoke pointing to local API when a flag is set.
- Weather-specific:
  - Unit-test the iOS weather context builder’s formatting and de-dup logic.

---

## Rollout

1) Refactor backend to pluggable `ChatBackend`; keep Anthropics default.
2) Add `LLMToolsBackend` (non-streaming) and env switch; verify end-to-end.
3) Add `ollama` + `chatterd` to compose; document local run.
4) Keep iOS baseline weather enrichment.
5) Optional: implement `/chat/tools` SSE path + iOS streaming client; validate server weather tool; decide on long-term default.

---

## Commands (for local dev)

> These are provided for convenience in local development; adjust as needed.

```sh
# Start Docker services (if you add ollama/chatterd services to docker-compose)
docker compose up -d

# Run API locally (if not containerized)
uvicorn api.server:app --reload --port 8000

# Switch backend to LLMTools for a smoke test (zsh)
export CHAT_BACKEND=llmtools
export CHATTERD_URL=http://127.0.0.1:5100

# Smoke test the non-streaming chat endpoint
curl -X POST http://127.0.0.1:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Suggest a casual fall outfit"}]}'
```
