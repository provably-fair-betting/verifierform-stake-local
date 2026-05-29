# verifierform-stake-local

Local E2E environment for testing the **Bet Lookup** feature end-to-end.

Wires together two pre-built images from GitHub Container Registry:

| Service | Image | Role |
|---|---|---|
| Frontend | `ghcr.io/provably-fair-betting/verifierform-stake:1` | Static SvelteKit SPA |
| API | `ghcr.io/provably-fair-betting/verifierform-stake-bet-lookup:1` | Laravel bet-lookup backend |

A single nginx reverse proxy serves both under one origin (`http://localhost:3000`), routing `/api/` to the backend and `/` to the frontend — no CORS configuration required.

---

## Architecture

```
Browser (http://localhost:3000)
  └── proxy (nginx)
       ├── /        → frontend (verifierform-stake image)
       └── /api/    → lookup-app (verifierform-stake-bet-lookup image) → lookup-db (MySQL)
```

---

## Prerequisites

- **Docker** with Compose v2 (`docker compose version`)

No local source checkouts or build tools required — all application images are pulled from the registry.

---

## Setup

### 1. First-time initialisation

```sh
make setup
```

Generates `APP_KEY`, admin token pair, and installs the capture script dependencies.

### 2. Start services

```sh
make up
```

Pulls the latest images and starts all containers. Opens at **http://localhost:3000**.

### 3. Run migrations

```sh
make migrate
```

Required on first start. Creates the `stake_clearance` table used by the bet-lookup API.

### 4. Capture Cloudflare clearance

```sh
make capture
```

The bet-lookup API proxies to `stake.games` which is protected by Cloudflare. This step opens a browser, lets you complete the challenge, and stores the resulting credentials. **Required for real bet lookups to work.**

---

## Day-to-day usage

| Command | Description |
|---|---|
| `make up` | Pull latest images and start all services |
| `make down` | Stop all services |
| `make logs` | Tail logs from all containers |
| `make migrate` | Run pending migrations |
| `make capture` | Refresh Cloudflare clearance credentials |
| `make reset` | Wipe Docker volumes (fresh database) |

---

## Configuration

Copy `.env.example` to `.env` to override defaults:

```sh
cp .env.example .env
```

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | Port the app is served on |

---

## How it connects

At startup the frontend container writes `BET_LOOKUP_URL=http://localhost:${PORT}` into `config.json`, which the SPA fetches on load to enable the Bet Lookup panel. The SPA calls `/api/bet-lookup` on the same origin; the proxy routes those requests to `lookup-app` — no CORS headers needed.
