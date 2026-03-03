# Switchboard Frontend

A real-time fundraising dashboard that streams live donation activity via Server-Sent Events (SSE).

## Features

- Live donation feed via SSE from the backend
- Summary stats: all-time total, last 7 days, last 24 hours
- Filter donations by referral code
- Keeps the 200 most recent donations in memory, displays up to 50

## Tech Stack

- React 19 + TypeScript
- Vite 7

## Getting Started

**Prerequisites:** Node.js and a running backend at `http://localhost:8000`

```bash
npm install
npm run dev
```

The dev server proxies `/stream` and `/webhook` to the backend, so no CORS config is needed.

## Backend Contract

The frontend connects to `GET /stream` and expects a newline-delimited SSE stream where each `data:` event is a JSON object:

```json
{
  "id": "string",
  "firstname": "string",
  "lastname": "string",
  "amount": 123,
  "refcode": "string",
  "timestamp": "2026-03-02T00:00:00Z"
}
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (with proxy) |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
