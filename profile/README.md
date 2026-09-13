# School Bajar

School supplies delivery platform for Gujarat, India. Parents and students order books, uniforms, shoes, and school kits — delivered to home or handed to the student at school.

## Repository Structure

```
School Bajar/
├── backend/          # Django API (this README focuses on backend)
├── docs/             # API contract, env vars, security
└── ...
```

## Backend Quick Start

### Prerequisites

- Docker & Docker Compose
- (Optional) Python 3.12 + PostGIS for local dev outside Docker

### Run with Docker

```bash
cd backend
cp .env.example .env   # or use the included .env for local dev
docker compose up --build -d
docker compose exec web python manage.py migrate
docker compose exec web python manage.py seed_demo
```

API: http://localhost:8000/api/docs/  
WebSocket (Daphne): ws://localhost:8001/ws/v1/

### Demo Users (after seed_demo)

| Role | Phone | Password |
|------|-------|----------|
| Owner | +919999999999 | owner12345 |
| Customer | +919999999997 | customer123 |
| Partner | +919999999996 | partner123 |

### Run Tests

```bash
docker compose exec web pytest
```

Or locally (requires PostGIS):

```bash
cd backend
pip install -r requirements.txt
export DJANGO_SETTINGS_MODULE=schoolbajar.settings.development
pytest
```

## Services (docker-compose)

| Service | Port | Purpose |
|---------|------|---------|
| web | 8000 | Django HTTP API |
| daphne | 8001 | WebSocket ASGI |
| db | 5432 | PostgreSQL 16 + PostGIS |
| redis | 6379 | Channels + Celery |
| celery-worker | — | Async tasks |
| celery-beat | — | Scheduled tasks |

## Documentation

- [API Contract](docs/API_CONTRACT.md) — REST endpoints + WebSocket schemas
- [Schedule & Routes API](docs/API_CONTRACT_SCHEDULE_AND_ROUTES.md) — delivery slots, multi-stop routes, OTP-free register
- [Deploy & Hardening](docs/DEPLOY_STATIC_AND_HARDENING.md) — HTTPS, Vue public site + `/privacy` `/terms`, app client key
- [Desktop Releases](docs/DESKTOP_RELEASES.md) — OTP-gated `.exe`/`.dmg` publish + download
- [Environment Variables](docs/ENV.example) — all `SCHOOLBAJAR_*` vars
- [Security Checklist](docs/SECURITY.md)
- [Local Setup](docs/LOCAL_SETUP.md)

## Production Deploy (VPS with existing Postgres + Redis)

Do **not** run `docker compose up` on the VPS — that file starts extra Postgres/Redis and will fight host `:5432` / `:6379`.

1. Create a dedicated DB + PostGIS: `scripts/prepare_host_postgres.sql`
2. `.env`: `SCHOOLBAJAR_DB_HOST=127.0.0.1` and `SCHOOLBAJAR_REDIS_URL=redis://127.0.0.1:6379/1` (plus secret, app client key, `DEBUG=False`)
3. `docker compose -f docker-compose.prod.yml up --build -d`
4. `docker compose -f docker-compose.prod.yml exec web python manage.py migrate`
5. `docker compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput`
6. Point existing Nginx: `/` → Vue `dist/` (`schoolbajar-frontend`), `/api/` → Gunicorn, `/ws/` → Daphne — see `nginx/nginx.conf.sample`. On the shared VPS this is `127.0.0.1:8010` / `:8011`.

## Tech Stack

- Django 5.x + DRF + PostGIS
- Django Channels + Redis (WebSockets)
- Celery + Redis (tasks)
- JWT (simplejwt with rotation + blacklist)
- Cashfree, Firebase FCM, Google Maps (server-side only)
