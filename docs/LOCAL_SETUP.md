# School Bajar — Local Development Setup

Run the full School Bajar stack on your laptop: backend, desktop, and all three mobile apps.

**Project root:** `SchoolMartGroup/`

| Service | URL |
|---------|-----|
| REST API | http://localhost:8000/api/v1/ |
| API docs (Swagger) | http://localhost:8000/api/docs/ |
| Django admin | http://localhost:8000/admin/ |
| WebSocket (Daphne) | ws://localhost:8001/ws/v1/ |
| Desktop (Vite dev) | http://localhost:1420 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

---

## 1. Prerequisites

Install once on your laptop:

| Tool | Version | Check |
|------|---------|-------|
| Docker + Docker Compose | latest | `docker compose version` |
| Node.js | 20+ | `node -v` |
| Rust (for Tauri) | latest | `rustc -V` |
| Flutter | 3.x | `flutter doctor` |
| Android Studio | optional | emulator + SDK |
| Linux Tauri deps | Ubuntu/Debian | see below |

### Linux — Tauri system packages

```bash
sudo apt update
sudo apt install -y libwebkit2gtk-4.1-dev build-essential curl wget file \
  libssl-dev libayatana-appindicator3-dev librsvg2-dev
```

### Flutter doctor

```bash
flutter doctor
```

Fix any issues (Android licenses: `flutter doctor --android-licenses`).

---

## 2. Open the project

```bash
cd ~/Desktop/SchoolMartGroup
```

---

## 3. Backend setup

### 3.1 Environment file

`schoolbajar-backend/.env` already exists. For Docker, the DB host is overridden to `db` in `docker-compose.yml`.

Minimum for local MVP (maps/push/payments optional at first):

```env
SCHOOLBAJAR_SECRET_KEY=dev-secret-key-change-in-production
SCHOOLBAJAR_DEBUG=True
SCHOOLBAJAR_ALLOWED_HOSTS=localhost,127.0.0.1,web,0.0.0.0
SCHOOLBAJAR_DB_NAME=schoolbajar
SCHOOLBAJAR_DB_USER=schoolbajar
SCHOOLBAJAR_DB_PASSWORD=schoolbajar
SCHOOLBAJAR_DB_HOST=localhost
SCHOOLBAJAR_DB_PORT=5432
SCHOOLBAJAR_REDIS_URL=redis://localhost:6379/0
SCHOOLBAJAR_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:1420
SCHOOLBAJAR_OTP_BYPASS_CODE=000000

# Optional — add when testing maps/routing
SCHOOLBAJAR_GOOGLE_MAPS_SERVER_KEY=

# Optional — add when testing Cashfree
SCHOOLBAJAR_CASHFREE_APP_ID=
SCHOOLBAJAR_CASHFREE_SECRET_KEY=
SCHOOLBAJAR_CASHFREE_ENV=SANDBOX

# Optional — add when testing push from server
SCHOOLBAJAR_FIREBASE_CREDENTIALS_PATH=
```

### 3.2 Start backend (Docker)

```bash
cd schoolbajar-backend
docker compose up --build -d
```

Wait ~30–60 seconds for Postgres health checks.

### 3.3 Database migrate + demo data

```bash
docker compose exec web python manage.py migrate
docker compose exec web python manage.py seed_demo
```

### 3.4 Verify backend

```bash
# Swagger UI in browser
xdg-open http://localhost:8000/api/docs/

# Test login (curl)
curl -s -X POST http://localhost:8000/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919999999999","password":"owner12345"}'
```

You should get JSON with `access` and `refresh` tokens.

### 3.5 Backend services running

```bash
docker compose ps
```

Expected services: `db`, `redis`, `web` (port 8000), `daphne` (port 8001), `celery-worker`, `celery-beat`.

### 3.6 Stop backend

```bash
cd schoolbajar-backend
docker compose down
```

Data persists in Docker volumes. Full reset:

```bash
docker compose down -v
```

---

## 4. Demo user accounts

Created by `seed_demo`:

| Role | Phone | Password | App |
|------|-------|----------|-----|
| Owner | `+919999999999` | `owner12345` | Admin mobile, Desktop (Store + Admin) |
| Staff | `+919999999998` | `staff12345` | Partner app (Staff), Desktop (Store) |
| Customer | `+919999999997` | `customer123` | Customer app |
| Partner | `+919999999996` | `partner123` | Partner app (Delivery) |

Demo school: **Demo Public School**, Ahmedabad.  
Demo products: books, uniform, shoes, ID card (100 stock each).

---

## 5. Google Maps keys (needed for map screens)

Create a Google Cloud project and enable:

- Maps SDK for Android
- Maps SDK for iOS
- Maps JavaScript API (+ Drawing Library for desktop geofences)
- Directions API, Geocoding API, Distance Matrix API (backend)

| Where | Key type | Variable |
|-------|----------|----------|
| Backend `.env` | Server key (IP restricted) | `SCHOOLBAJAR_GOOGLE_MAPS_SERVER_KEY` |
| Flutter Android | Android key | `AndroidManifest.xml` or `local.properties` |
| Flutter iOS | iOS key | `AppDelegate.swift` |
| Desktop `.env` | Browser key | `VITE_GOOGLE_MAPS_JS_KEY` |

**Without keys:** apps run, but map tiles and routing will be blank or fail.

---

## 6. Desktop app (Tauri 2 + Vue)

### 6.1 Setup

```bash
cd schoolbajar-desktop
cp .env.example .env   # skip if .env already exists
npm install
```

Edit `.env`:

```env
VITE_API_URL=http://localhost:8000/api/v1
VITE_WS_URL=ws://localhost:8001/ws/v1
VITE_GOOGLE_MAPS_JS_KEY=your_js_api_key
```

### 6.2 Run (web — fastest for UI check)

```bash
npm run dev
```

Open http://localhost:1420 — login with owner credentials.

### 6.3 Run (native Tauri window)

```bash
npm run tauri:dev
```

### 6.4 Login

- Phone: `+919999999999`
- Password: `owner12345`

---

## 7. Mobile apps (Flutter)

### 7.1 Install dependencies (each app once)

```bash
cd schoolbajar-core && flutter pub get && cd ..

cd schoolbajar-admin && flutter pub get && cd ..
cd schoolbajar-partner && flutter pub get && cd ..
cd schoolbajar-customer && flutter pub get && cd ..
```

### 7.2 API URL by device

| Target | `API_BASE_URL` | `WS_BASE_URL` |
|--------|----------------|---------------|
| Android emulator | `http://10.0.2.2:8000/api/v1` | `ws://10.0.2.2:8001` |
| iOS simulator | `http://localhost:8000/api/v1` | `ws://localhost:8001` |
| Physical phone (same Wi‑Fi) | `http://<LAPTOP_LAN_IP>:8000/api/v1` | `ws://<LAPTOP_LAN_IP>:8001` |
| Flutter on Linux desktop | `http://localhost:8000/api/v1` | `ws://localhost:8001` |

Find LAN IP:

```bash
hostname -I | awk '{print $1}'
```

For physical phone, add your LAN IP to `SCHOOLBAJAR_ALLOWED_HOSTS` in `schoolbajar-backend/.env` and restart:

```bash
cd schoolbajar-backend && docker compose restart web daphne
```

### 7.3 Run Admin app

```bash
cd schoolbajar-admin
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001
```

### 7.4 Run Partner app

```bash
cd schoolbajar-partner
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001
```

Gradle uses an isolated cache automatically (via `android/gradlew`) so you do not need to set `GRADLE_USER_HOME` manually. If build still fails, run `./scripts/repair-android-build.sh partner`.

### 7.5 Run Customer app

```bash
cd schoolbajar-customer
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001 \
  --dart-define=SUPPORT_PHONE=+919876543210 \
  --dart-define=SHOP_UPI_ID=schoolbajar@upi
```

---

## 8. Optional: Firebase FCM (push notifications)

Apps run **without** Firebase. Push is skipped until configured.

1. Create Firebase project
2. Add Android/iOS apps per package (`com.schoolbajar.admin`, `com.schoolbajar.partner`, `com.schoolbajar.customer`)
3. Place `google-services.json` / `GoogleService-Info.plist`
4. Backend: set `SCHOOLBAJAR_FIREBASE_CREDENTIALS_PATH` to service account JSON
5. Restart celery-worker: `docker compose restart celery-worker`

---

## 9. Optional: Cashfree (online payments)

1. Add Cashfree sandbox App ID + Secret Key to `schoolbajar-backend/.env`
2. Restart: `docker compose restart web celery-worker`
3. Point Cashfree webhook to `POST /api/v1/payments/webhook/cashfree/`
4. Test in Customer app checkout

**COD and UPI manual work without Cashfree.**

---

## 10. Full local startup (quick checklist)

Open **6 terminals**:

```bash
# Terminal 1 — Backend
cd ~/Desktop/SchoolMartGroup/schoolbajar-backend
docker compose up

# Terminal 2 — Desktop
cd ~/Desktop/SchoolMartGroup/schoolbajar-desktop
npm run dev

# Terminal 3 — Admin app
cd ~/Desktop/SchoolMartGroup/schoolbajar-admin
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001

# Terminal 4 — Partner app
cd ~/Desktop/SchoolMartGroup/schoolbajar-partner
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001

# Terminal 5 — Customer app
cd ~/Desktop/SchoolMartGroup/schoolbajar-customer
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_BASE_URL=ws://10.0.2.2:8001

# Terminal 6 — Watch logs (optional)
cd ~/Desktop/SchoolMartGroup/schoolbajar-backend
docker compose logs -f web daphne celery-worker
```

---

## 11. Frontend verification (development)

Use this order to test the full order lifecycle across all apps.

### Phase 0 — Smoke test

| Check | How | Pass criteria |
|-------|-----|---------------|
| API alive | Open http://localhost:8000/api/docs/ | Swagger loads |
| Login API | Owner login in Swagger `POST /auth/login/` | Returns tokens |
| Desktop loads | http://localhost:1420 | Login page renders |
| Flutter apps launch | `flutter run` each app | No crash on splash |

### Phase 1 — Desktop (Store + Admin modes)

**Login:** `+919999999999` / `owner12345`

**Store mode:**

1. Dashboard — tiles show sales/pending/low stock
2. Products — 4 demo products visible; add/edit works
3. Stock — ~100 qty per SKU; adjustment updates quantity
4. POS — search product → cart → complete COD sale → receipt modal
5. Orders — POS order appears in queue
6. Receipts — search and open PDF

**Admin mode (Owner only):**

1. Fleet map — Google Map loads; WebSocket shows "Live"
2. Geofences — draw polygon around Demo Public School → save
3. Schools — view/edit Demo Public School
4. Partners — Demo Partner visible
5. Reports — chart/table renders

### Phase 2 — Customer app

**Login:** `+919999999997` / `customer123`

1. Guest browse — categories and products without login
2. Add to cart → login at checkout → cart merges
3. Add student at Demo School, Class 5, Section A
4. Checkout with home delivery + COD → order success
5. Orders tab — new order with status timeline
6. Optional: school delivery, UPI manual, Cashfree (if keys configured)

### Phase 3 — Partner app (Staff mode)

**Login:** `+919999999998` / `staff12345`

1. Pack queue — open customer order
2. Mark all packed → status PACKED
3. School batches — group by school (if school order)
4. UPI verify — approve/reject pending payment

### Phase 4 — Admin mobile app

**Login:** `+919999999999` / `owner12345`

1. Dashboard — KPI cards and recent orders
2. Orders — find customer order → open detail
3. Assign partner → Demo Partner
4. Fleet tab — map loads; partner marker when on duty
5. Reports — sales chart (Owner only)

### Phase 5 — Partner app (Delivery mode)

**Login:** `+919999999996` / `partner123`

1. Switch to Delivery mode → toggle ON DUTY
2. Open assigned delivery → map + route (needs Google keys)
3. Picked up → Start delivery → OUT_FOR_DELIVERY
4. Verify location on Admin Fleet / Desktop Fleet map
5. Delivered → optional photo → COMPLETED
6. Toggle OFF DUTY — location stops

**Emulator GPS:** Android Studio → Extended Controls → Location → set `23.0225, 72.5714` (Ahmedabad).

### Phase 6 — Customer live tracking

With partner OUT_FOR_DELIVERY:

1. Customer → order → Track delivery
2. Partner marker moves on map
3. Route polyline visible (needs Google keys)
4. Status updates via WebSocket without manual refresh

### Phase 7 — Cross-app real-time

Run Admin Fleet + Desktop Admin Fleet + Customer tracking at the same time:

| Event | Admin app | Desktop admin | Customer app |
|-------|-----------|---------------|--------------|
| Partner ON DUTY | Marker appears | Marker appears | — |
| Location ping | Marker moves | Marker moves | Partner dot moves |
| Status change | Order list updates | Live orders updates | Timeline updates |
| Geofence ENTER | Toast/event | Map event | "Reached school area" |

### Static analysis

```bash
cd schoolbajar-admin && flutter analyze
cd ../schoolbajar-partner && flutter analyze
cd ../schoolbajar-customer && flutter analyze
cd ../schoolbajar-desktop && npm run build
```

---

## 12. What works without extra setup

| Feature | Works without Google/Firebase/Cashfree? |
|---------|----------------------------------------|
| Login, catalog, cart, orders | Yes |
| COD checkout | Yes |
| POS on desktop | Yes |
| Pack / assign / status flow | Yes |
| WebSocket (non-map) | Yes |
| Maps, routing, geofence draw | Needs Google keys |
| Cashfree checkout | Needs Cashfree sandbox keys |
| Server push (FCM) | Needs Firebase + credentials |

---

## 13. Recommended first-time path (~30–45 min)

1. `docker compose up` → `migrate` → `seed_demo`
2. Desktop Store: verify products + POS sale
3. Customer: COD order (home delivery)
4. Partner Staff: pack order
5. Admin mobile: assign partner
6. Partner Delivery: complete delivery
7. Customer: order detail + receipt
8. Desktop Admin: draw geofence (if Google key set)
9. Admin Fleet + Customer tracking together

---

## 14. Troubleshooting

| Problem | Fix |
|---------|-----|
| `Truncated class file` / Gradle build fails | Corrupted `~/.gradle` cache. Run `./scripts/run-mobile-app.sh partner` or `export GRADLE_USER_HOME=/tmp/gradle-schoolbajar-$(whoami)` before `flutter run`. Full reset: `./scripts/repair-android-build.sh partner` |
| `Connection refused` on mobile | Use `10.0.2.2` (emulator) or LAN IP (phone), not `localhost` |
| CORS error on desktop | Ensure `http://localhost:1420` in CORS; dev mode allows all origins |
| Maps blank | Add Google API keys; enable billing on Google Cloud |
| WebSocket fails | Check Daphne on port 8001: `docker compose ps` |
| Login 401 | Use exact demo phones with `+91` prefix |
| Receipt PDF missing | Celery worker must be running |
| `seed_demo` already run | Safe to re-run; uses `get_or_create` |
| Port 5432 busy | Stop local Postgres or change compose port |

### Useful commands

```bash
# Backend logs
docker compose logs -f web

# Django shell
docker compose exec web python manage.py shell

# Re-run migrations
docker compose exec web python manage.py migrate

# Restart after .env change
docker compose restart web daphne celery-worker
```

---

## 15. Related docs

- [API_CONTRACT.md](./API_CONTRACT.md) — all REST endpoints and WebSocket message formats
- [API_CONTRACT_SCHEDULE_AND_ROUTES.md](./API_CONTRACT_SCHEDULE_AND_ROUTES.md) — delivery schedule, slots, multi-stop routes, OTP-free register
- [DEPLOY_STATIC_AND_HARDENING.md](./DEPLOY_STATIC_AND_HARDENING.md) — HTTPS, Vue `/` + `/privacy`/`/terms`, `/api`, `/ws`, app client key
- [DESKTOP_RELEASES.md](./DESKTOP_RELEASES.md) — OTP-gated desktop installer publish/download
- [ENV.example](./ENV.example) — full environment variable reference
- [SECURITY.md](./SECURITY.md) — security checklist
- App-specific READMEs:
  - `schoolbajar-admin/README.md`
  - `schoolbajar-partner/README.md`
  - `schoolbajar-customer/README.md`
  - `schoolbajar-desktop/README.md`
