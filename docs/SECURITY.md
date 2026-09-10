# School Bajar Security Checklist

## Secrets & Configuration

- [ ] `SCHOOLBAJAR_SECRET_KEY` is unique per environment and never committed
- [ ] Database credentials stored in environment variables only
- [ ] `SCHOOLBAJAR_GOOGLE_MAPS_SERVER_KEY` is server-restricted; not embedded in mobile/web clients
- [ ] Cashfree App ID and secret key in env only
- [ ] Firebase service account JSON mounted as secret file, not in repo
- [ ] `DEBUG=False` in production (`schoolbajar.settings.production`)

## Transport & Cookies

- [ ] HTTPS enforced via Nginx (`nginx/nginx.conf.sample`)
- [ ] HSTS enabled in production settings
- [ ] Secure session and CSRF cookies in production
- [ ] WebSocket connections proxied with `Upgrade` headers over TLS

## Authentication

- [x] JWT access tokens expire in 15 minutes
- [x] Refresh token rotation with blacklist on logout
- [x] Login rate limited to 5/min per IP
- [x] Per-phone login throttle + cache lockout after N failures (generic "Invalid credentials")
- [x] Password validators enabled (Django defaults) on registration
- [x] Passwords and tokens never logged; logout does not echo tokens
- [x] Token refresh is AllowAny + AuthRateThrottle
- [x] Register is CUSTOMER-only (role / privilege escalation rejected)
- [x] `UserUpdateSerializer` cannot set role / is_staff / is_superuser / phone

## WebSockets

- [ ] **Never** put long-lived access/refresh JWTs in `?token=` (leaks via proxy/access logs)
- [ ] Prefer `Authorization: Bearer` + `X-SchoolBajar-App-Key` on the WS handshake (native clients)
- [ ] Browser/desktop clients mint a **single-use short-lived ticket** via `POST /api/v1/auth/ws-ticket/` (HTTP already gated by app key + JWT), then connect with `?ticket=` only
- [ ] First-message auth `{"type":"auth","token":"...","app_key":"..."}` is allowed as a fallback; do not log that frame
- [ ] WS paths are outside `AppClientKeyMiddleware` — enforce the same app key via header, first-message `app_key`, or ticket minted after keyed HTTP
- [ ] Reject oversized inbound JSON frames (close 1009); rate-limit partner `location_ping` on WS
- [ ] Do not broadcast other users' PII on WS (location/order payloads use IDs, not phones/names)

## Authorization

- [x] RBAC enforced per endpoint (OWNER, STAFF, PARTNER, CUSTOMER); backend is source of truth (fail closed)
- [x] COD confirm scoped to order customer owner or OWNER/STAFF (no bare `Order.objects.get`)
- [x] Stock list OWNER/STAFF/PARTNER only; suppliers / purchase orders OWNER/STAFF only (no CUSTOMER cost data)
- [x] Cart + checkout CUSTOMER-only; POS OWNER/STAFF-only
- [x] Students: CUSTOMER sees/edits own only; mass-assign `customer` rejected
- [x] Anonymous catalog/schools GET safe (no `AnonymousUser.role` AttributeError); inactive schools/products hidden
- [x] Partner `cash_in_hand` only for self or OWNER/STAFF in serializers
- [x] App client key wrong/missing/length-mismatch → 403 (not 500); OPTIONS safe for CORS
- [ ] WebSocket connections require valid JWT (header, ticket, or first-message)
- [ ] Fleet WS: OWNER/STAFF only (partners denied)
- [ ] Partner WS: PARTNER only (customers denied)
- [x] Order tracking limited to customer, assigned partner, OWNER, STAFF (random order UUID denied)
- [ ] Fleet map and geofence management limited to OWNER/STAFF

## Input Validation

- [x] All input via DRF serializers
- [ ] ORM-only database access (no raw SQL with user input); `SalesReportView` uses `TruncDate` (not `QuerySet.extra`)
- [ ] Image uploads: max 5MB; JPEG/PNG/WebP only; extension allowlist + magic-byte / Pillow sniff; SVG/HTML/XML rejected
- [ ] Upload storage names use basename + UUID — never trust `UploadedFile.name` for paths (`delivery_proof`, catalog, student photos)
- [ ] Receipt PDF download: `Path.resolve()` must stay under `MEDIA_ROOT`; other customers get 403
- [ ] DRF pagination capped (`BoundedPageNumberPagination.max_page_size=100`)
- [x] Order status transitions validated server-side
- [x] Search `q` length capped; cart metadata / checkout address JSON schema-checked
- [x] Geocode heavily throttled; roles restricted; client URLs rejected (no user URLs into HTTP clients)
- [ ] Django templates: no `|safe` / `mark_safe` abuse (receipt HTML auto-escapes)

## Payments

- [x] Cashfree order status verified on client callback via server `verify_order_paid` (never trust client paid flag)
- [x] Cashfree create/verify scoped to `order__customer`
- [x] Cashfree webhook signature verified (`x-webhook-signature` + timestamp)
- [x] Webhook rejects missing/stale timestamp (replay window) + throttled; AllowAny only with those checks
- [x] Webhook handler is idempotent (duplicate `cashfree_payment_id` ignored)
- [x] UPI manual payments require STAFF verification

## Data Integrity

- [ ] Stock changes use atomic transactions (ledger + balance)
- [ ] Order checkout, payment, and cancellation use transactions
- [ ] Immutable audit trails: `StockLedger`, `OrderStatusHistory`, `GeofenceEvent`

## CORS

- [ ] Production: explicit `SCHOOLBAJAR_CORS_ALLOWED_ORIGINS` only
- [ ] Development: permissive CORS for local apps only

## Infrastructure

- [ ] **Media default deny:** public `/media/` returns 403; bytes via nginx `internal` `/protected-media/` + Django `X-Accel-Redirect` after auth (`MediaServeView`, `ReceiptDownloadView`, desktop OTP download)
- [ ] Production `MEDIA_URL=/api/v1/media/`; catalog `products/` + `categories/` are public-read on the gate (app key still required); `students/` owner/staff/owning-customer/assigned-partner; receipts/desktop OWNER/STAFF; delivery_proofs OWNER/STAFF/PARTNER. DEBUG `django.conf.urls.static` is **not** the prod model
- [ ] Flutter/desktop: do not use bare `Image.network` / `<img>` for gated media — use Dio/`AuthenticatedNetworkImage` (JWT + app key) or ownership-checked download endpoints
- [ ] Security headers: `SECURE_CONTENT_TYPE_NOSNIFF`, `SECURE_REFERRER_POLICY`, `X_FRAME_OPTIONS=DENY`; nginx `nosniff` / `DENY` / Referrer-Policy / Permissions-Policy / CSP (`default-src 'none'` on API; tight CSP on `/privacy` `/terms`)
- [ ] nginx: `server_tokens off`, `autoindex off`, TRACE/non-API methods limited; desktop 500MiB body only on `/api/v1/desktop/releases/`
- [ ] Gunicorn/Daphne bind `127.0.0.1`; nginx only public
- [ ] PostgreSQL not exposed publicly
- [ ] Redis not exposed publicly
- [ ] Regular backups of PostgreSQL

## Monitoring

- [ ] Structured logging without sensitive fields
- [ ] Failed auth and webhook verification logged
- [ ] Location ping retention: 30 days (Celery cleanup task)

## Desktop (Tauri / Vue)

- [ ] Production CSP: `connect-src` limited to `https://schoolbajar.com` / `wss://schoolbajar.com` (+ Maps); no `'unsafe-eval'`; `object-src 'none'`; `base-uri 'self'`; `frame-ancestors 'none'`
- [ ] Dev CSP (`devCsp`) may allow localhost HTTP/WS and `'unsafe-eval'` for Vite HMR only
- [ ] Access/refresh JWTs never stored in `localStorage` in production — Tauri plugin-store only (AES-GCM wrapped values; not OS keychain — no new plugin)
- [ ] `shell:allow-open` URL allowlist: `https://(www.)?schoolbajar.com/...` via `plugins.shell.open`
- [ ] Store capability limited to load/get/set/delete/clear/save/has (not full `store:default`)
- [ ] No `v-html` / `innerHTML` / `document.write` of API data; receipts/slips text-interpolated + sanitize
- [ ] Axios/fetch diagnostics never print `Authorization` or tokens in production
- [ ] Production `VITE_API_URL` must be `https://`; `VITE_WS_URL` must be `wss://`
- [ ] WebSocket: prefer `POST /auth/ws-ticket/` then `?ticket=` (opaque); fallback first-message `{"type":"auth","token","app_key","app_id"}` — never JWT in query
- [ ] `VITE_APP_CLIENT_KEY` is extractable from the bundle (bump-in-the-wire); rotate by rebuild + backend key change
- [ ] Vue router guards are UX only; server RBAC remains authoritative

## Flutter clients (customer / partner / admin)

### Token storage

- [x] JWT access/refresh tokens stored only in `flutter_secure_storage` (`schoolbajar-core` `SecureStorage`)
- [x] SharedPreferences used only for non-secret prefs (onboarding, guest cart, mode, notification toggle, offline retry queue payload without JWTs)
- [x] Deep links / FCM payloads must not carry tokens — navigate by resource id only (`sanitizeDeepLinkUri`)

### Logging

- [x] Dio `LogInterceptor(requestBody: true)` enabled only when `kDebugMode` (never in release)
- [x] Debug logs redact `Authorization: Bearer …` and `X-SchoolBajar-App-Key`

### Transport

- [x] Android release: `usesCleartextTraffic=false` + network security config denying cleartext; debug allows localhost / `10.0.2.2` only
- [x] iOS ATS: `NSAllowsArbitraryLoads=false` (localhost exception for local debug)
- [ ] **Certificate pinning skipped** for now — pin rotation on `schoolbajar.com` without a coordinated update channel risks bricking apps. Residual risk: MITM on compromised device trust stores. Revisit with bundled SPKI pins + documented rotation when ops owns cert lifecycle.

### UI / XSS surface

- [x] No `WebView` / `Html()` / `innerHTML` of API strings — Text widgets only
- [x] External links via allowlisted `launchAllowedUrl` (`https://schoolbajar.com` privacy/terms, tel/WhatsApp support, Google Maps navigation, configured API HTTPS host for receipts)
- [x] Android `FLAG_SECURE` on auth and payment screens via platform channel (`SecureScreenScope`) — no third-party screen-security libs
- [x] Flutter web `web/index.html` CSP on all three apps (web is not the primary store channel; CSP still reduces XSS blast radius)
- [x] Customer OTP login remains removed (password + trusted phone entry only)

### App client key

- [x] `APP_CLIENT_KEY` required in release builds (`ApiClient`); sent as `X-SchoolBajar-App-Key`
- [ ] Residual risk: key is extractable from the APK/IPA (bump-in-the-wire only). Do **not** put Maps **server** keys or Cashfree secrets in `--dart-define`. Rotate `SCHOOLBAJAR_APP_CLIENT_KEY` if leaked; prefer per-app keys when available.

### Partner location UI

- [x] Partner delivery UI renders only the assigned order returned by the API for the authenticated partner (no client-side browse of other customers' PII beyond API responses)

## Related

See [DEPLOY_STATIC_AND_HARDENING.md](./DEPLOY_STATIC_AND_HARDENING.md) for HTTPS layout, `/privacy`/`/terms`, and app client key gating.
