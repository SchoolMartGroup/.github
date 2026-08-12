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
- [Environment Variables](docs/ENV.example) — all `SCHOOLBAJAR_*` vars
- [Security Checklist](docs/SECURITY.md)

## Production Deploy

1. Set `DJANGO_SETTINGS_MODULE=schoolbajar.settings.production`
2. Configure all `SCHOOLBAJAR_*` env vars (see `docs/ENV.example`)
3. Use Nginx sample config: `backend/nginx/nginx.conf.sample`
4. Run migrations and collect static files
5. Mount `media/` volume for uploads and receipt PDFs

## Tech Stack

- Django 5.x + DRF + PostGIS
- Django Channels + Redis (WebSockets)
- Celery + Redis (tasks)
- JWT (simplejwt with rotation + blacklist)
- Cashfree, Firebase FCM, Google Maps (server-side only)
