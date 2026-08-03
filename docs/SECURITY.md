# SchoolMart Security Checklist

## Secrets & Configuration

- [ ] `SCHOOLMART_SECRET_KEY` is unique per environment and never committed
- [ ] Database credentials stored in environment variables only
- [ ] `SCHOOLMART_GOOGLE_MAPS_SERVER_KEY` is server-restricted; not embedded in mobile/web clients
- [ ] Cashfree App ID and secret key in env only
- [ ] Firebase service account JSON mounted as secret file, not in repo
- [ ] `DEBUG=False` in production (`schoolmart.settings.production`)

## Transport & Cookies

- [ ] HTTPS enforced via Nginx (`nginx/nginx.conf.sample`)
- [ ] HSTS enabled in production settings
- [ ] Secure session and CSRF cookies in production
- [ ] WebSocket connections proxied with `Upgrade` headers over TLS

## Authentication

- [ ] JWT access tokens expire in 15 minutes
- [ ] Refresh token rotation with blacklist on logout
- [ ] Login rate limited to 5/min per IP
- [ ] Password validators enabled (Django defaults)
- [ ] Passwords and tokens never logged

## Authorization

- [ ] RBAC enforced per endpoint (OWNER, STAFF, PARTNER, CUSTOMER)
- [ ] WebSocket connections require valid JWT
- [ ] Order tracking limited to customer, assigned partner, OWNER, STAFF
- [ ] Fleet map and geofence management limited to OWNER/STAFF

## Input Validation

- [ ] All input via DRF serializers
- [ ] ORM-only database access (no raw SQL with user input)
- [ ] Image uploads validated: max 5MB, JPEG/PNG/WebP only
- [ ] Order status transitions validated server-side

## Payments

- [ ] Cashfree order status verified on client callback (`order_status == PAID`)
- [ ] Cashfree webhook signature verified (`x-webhook-signature` + timestamp)
- [ ] Webhook handler is idempotent (duplicate `cashfree_payment_id` ignored)
- [ ] UPI manual payments require STAFF verification

## Data Integrity

- [ ] Stock changes use atomic transactions (ledger + balance)
- [ ] Order checkout, payment, and cancellation use transactions
- [ ] Immutable audit trails: `StockLedger`, `OrderStatusHistory`, `GeofenceEvent`

## CORS

- [ ] Production: explicit `SCHOOLMART_CORS_ALLOWED_ORIGINS` only
- [ ] Development: permissive CORS for local apps only

## Infrastructure

- [ ] Media files served via Nginx, not Django in production
- [ ] PostgreSQL not exposed publicly
- [ ] Redis not exposed publicly
- [ ] Regular backups of PostgreSQL

## Monitoring

- [ ] Structured logging without sensitive fields
- [ ] Failed auth and webhook verification logged
- [ ] Location ping retention: 30 days (Celery cleanup task)
