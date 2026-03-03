# Switchboard Backend

A lightweight Ruby/Sinatra webhook receiver and real-time broadcast server for ActBlue donation events.

## How it works

1. ActBlue sends a webhook `POST /webhook/actblue_donation` when a donation is made.
2. The backend validates the payload, deduplicates it using a SHA-256 idempotency key, and broadcasts the donation to all connected clients over **Server-Sent Events (SSE)**.
3. Frontend clients connect to `GET /stream` and receive donation events in real time.

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | None | Health check — returns `{ status: "ok" }` |
| `GET` | `/stream` | None | SSE stream; emits `data:` events for each donation |
| `POST` | `/webhook/actblue_donation` | Basic Auth | Receives ActBlue donation webhooks |

## Setup

### Prerequisites

- Ruby (see `.ruby-version`)
- Bundler

### Install dependencies

```bash
bundle install
```

### Environment variables

Create a `.env` file in this directory:

```env
AUTH_USER=your_webhook_username
AUTH_PASSWORD=your_webhook_password
PORT=8000                  # optional, defaults to 8000
```

`AUTH_USER` and `AUTH_PASSWORD` are the HTTP Basic Auth credentials ActBlue sends with each webhook request.

### Run

```bash
ruby app.rb
```

The server listens on `localhost:$PORT` (default `8000`).

## Donation event shape

Each SSE `data:` payload is a JSON object:

```json
{
  "id":        "order number",
  "firstname": "Jane",
  "lastname":  "Doe",
  "email":     "jane@example.com",
  "amount":    25,
  "refcode":   "homepage",
  "timestamp": "2026-03-02T12:00:00Z",
  "recurring": false
}
```

## Deduplication

Duplicate webhooks are ignored in-memory using a SHA-256 hash of `orderNumber + paidAt + lineitemId`. Note: this state is not persisted — restarts will clear it.

## CORS

Requests from `http://localhost:5173` are allowed (the default Vite dev server origin). Update the `Access-Control-Allow-Origin` header in `app.rb` for production.
