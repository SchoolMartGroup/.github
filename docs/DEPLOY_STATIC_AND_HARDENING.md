# Deploy: static legal pages + API hardening

Production host: `https://schoolbajar.com`

## URL layout

| Path | Backend |
|------|---------|
| `/api/` | Django / Gunicorn (ASGI/WSGI) |
| `/privacy/` | Static HTML (`static_pages/privacy/index.html`) |
| `/terms/` | Static HTML (`static_pages/terms/index.html`) |
| `/admin/` | Prefer private network / VPN / IP allowlist — do not expose publicly if possible |
| `/api/schema/`, `/api/docs/` | Disabled when `DEBUG=False` (production settings) |

Public Play Store URLs:

- https://schoolbajar.com/privacy
- https://schoolbajar.com/terms

These pages are **outside** `/api` and are plain static HTML (not Django templates). Account deletion is **in-app only** (Customer app → Account → Delete account).

## Example nginx

```nginx
server {
    listen 443 ssl http2;
    server_name schoolbajar.com;

    # TLS certs via certbot / your provider
    # ssl_certificate     /etc/letsencrypt/live/schoolbajar.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/schoolbajar.com/privkey.pem;

    # Legal pages (static) — NOT under /api
    location /privacy/ {
        alias /var/www/schoolbajar/static_pages/privacy/;
        try_files $uri $uri/ /privacy/index.html;
    }
    location = /privacy {
        return 301 /privacy/;
    }

    location /terms/ {
        alias /var/www/schoolbajar/static_pages/terms/;
        try_files $uri $uri/ /terms/index.html;
    }
    location = /terms {
        return 301 /terms/;
    }

    # API → Django (docker-compose.prod.yml web)
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket → Daphne
    location /ws/ {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # Optional: lock down admin
    # location /admin/ {
    #     allow 10.0.0.0/8;
    #     deny all;
    #     proxy_pass http://127.0.0.1:8000;
    #     ...
    # }
}
```

Copy `schoolbajar-backend/static_pages/` to the server path used in `alias` (e.g. `/var/www/schoolbajar/static_pages/`).
Each of `privacy/` and `terms/` includes `logo-wordmark.png`, `logo-icon.png`, and `favicon.png` for relative URLs (no extra nginx location required). A shared copy also lives under `static_pages/assets/` if you prefer a single branding folder later.

## VPS: existing Postgres + Redis (no extra containers)

Use `docker-compose.prod.yml`. It runs only `web`, `daphne`, `celery-worker`, and `celery-beat` on the host network so they use `127.0.0.1:5432` and `127.0.0.1:6379`. It does not start Postgres or Redis.

```bash
# one-time: dedicated database + PostGIS (does not touch other DBs)
sudo -u postgres psql -f scripts/prepare_host_postgres.sql

# .env: SCHOOLBAJAR_DB_HOST=127.0.0.1
#       SCHOOLBAJAR_REDIS_URL=redis://127.0.0.1:6379/1

docker compose -f docker-compose.prod.yml up --build -d
docker compose -f docker-compose.prod.yml exec web python manage.py migrate
docker compose -f docker-compose.prod.yml exec web python manage.py collectstatic --noinput
```

Host Postgres must have the PostGIS extension. Redis DB index `1` keeps Celery/Channels off whatever already uses DB `0`. Nginx on the VPS should proxy `/api/` → `127.0.0.1:8000` and `/ws/` → `127.0.0.1:8001`. Compose binds gunicorn/daphne to loopback only.

## Required production env vars

```bash
SCHOOLBAJAR_SECRET_KEY=...          # strong secret
SCHOOLBAJAR_DEBUG=False
SCHOOLBAJAR_ALLOWED_HOSTS=schoolbajar.com
SCHOOLBAJAR_APP_CLIENT_KEY=...      # shared secret; Flutter sends as X-SchoolBajar-App-Key
SCHOOLBAJAR_CORS_ALLOWED_ORIGINS=   # empty/minimal — native apps; no random web origins
# Leave OTP bypass unset/empty in production (production.py forces ""):
# SCHOOLBAJAR_OTP_BYPASS_CODE=
```

Optional per-app keys (if set, both headers required):

```bash
SCHOOLBAJAR_APP_CLIENT_KEYS=customer:key1,partner:key2,admin:key3
```

Clients send:

- `X-SchoolBajar-App-Key: <secret>`
- optionally `X-SchoolBajar-App-Id: customer|partner|admin`

## Production hardening checklist

- [x] `DEBUG=False` via production settings
- [x] HTTPS redirect + HSTS (production.py)
- [x] `CORS_ALLOW_ALL_ORIGINS=False`
- [x] JSON-only DRF renderers when `DEBUG=False` (no browsable API)
- [x] Schema/Swagger routes omitted when `DEBUG=False`
- [x] App client key required on `/api/` requests
- [x] Default DRF permission `IsAuthenticated` (login/register/refresh remain `AllowAny` but still need app key)
- [x] OTP bypass cleared in production (`SCHOOLBAJAR_OTP_BYPASS_CODE=""`)
- [x] `SECURE_CONTENT_TYPE_NOSNIFF`, `SECURE_REFERRER_POLICY`, `X_FRAME_OPTIONS=DENY` (production.py)
- [x] Authenticated media gate: production `MEDIA_URL=/api/v1/media/` + nginx `/media/` deny + `/protected-media/` internal (see `nginx/nginx.conf.sample`)
- [x] Gunicorn/Daphne bind `127.0.0.1` in `docker-compose.prod.yml` (nginx only public)
- [ ] `ALLOWED_HOSTS` includes `schoolbajar.com`
- [ ] Do not log `SCHOOLBAJAR_SECRET_KEY`, `SCHOOLBAJAR_APP_CLIENT_KEY`, or payment secrets
- [ ] Prefer not exposing `/admin/` on the public internet
- [ ] Confirm nginx sample headers/CSP applied on the VPS (`schoolbajar-backend/nginx/nginx.conf.sample`)

## Media & uploads (production)

| Concern | Policy |
|---------|--------|
| Public `/media/` | **Denied** (403). Not a static alias. |
| File bytes | nginx `location /protected-media/ { internal; alias … }` |
| Auth gate | Django `GET /api/v1/media/<path>` (`MediaServeView`) or dedicated views (receipts, desktop OTP) set `X-Accel-Redirect` |
| DEBUG | `django.conf.urls.static` may serve `/media/` locally — **never** replicate in prod |
| Images | `validate_image_file`: extension allowlist, magic bytes + Pillow, reject SVG/HTML/XML; UUID storage names |
| Body size | Global nginx `client_max_body_size 5m`; desktop installers use dedicated `/api/v1/desktop/releases/` at 500m |

## Desktop installer distribution

See [DESKTOP_RELEASES.md](./DESKTOP_RELEASES.md) for OTP-gated `.exe`/`.dmg` publish + download, latest-version check, storage under `MEDIA_ROOT/desktop/releases/`, and `SCHOOLBAJAR_DESKTOP_MAX_UPLOAD_BYTES`.
