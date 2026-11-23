# School Bajar API Contract

Base URL: `/api/v1/`  
WebSocket base: `/ws/v1/`  
Auth: `Authorization: Bearer <access_token>`

Browser website (Vite): send `Authorization: Bearer` + `Content-Type`. Do **not** embed `SCHOOLBAJAR_APP_CLIENT_KEY` in JS. Requests whose `Origin` is in `SCHOOLBAJAR_WEB_ORIGINS` skip the app-key gate. Catalog images at `/api/v1/media/products/` and `/categories/` are GET-public (no JWT, no app key) so `<img>` works. Student photos and receipts need `fetch` + JWT (not raw `<img src>`).

OpenAPI schema: `/api/schema/`  
Swagger UI: `/api/docs/`

Related: [delivery schedule & multi-stop routes](./API_CONTRACT_SCHEDULE_AND_ROUTES.md) · [desktop releases](./DESKTOP_RELEASES.md) · [deploy & hardening](./DEPLOY_STATIC_AND_HARDENING.md)

---

## Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register/` | None | Register customer `{phone, password, full_name, otp?}` |
| POST | `/auth/login/` | None | Login `{phone, password}` → `{access, refresh}` |
| POST | `/auth/refresh/` | None | Refresh `{refresh}` → tokens |
| POST | `/auth/logout/` | JWT | Blacklist `{refresh}` |
| GET | `/auth/me/` | JWT | Current user + profile |
| PATCH | `/auth/me/` | JWT | Update `{full_name?, email?}` |
| POST | `/auth/device-token/` | JWT | Register FCM `{token, platform}` |

---

## Schools

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| GET/POST | `/schools/` | read / OWNER,STAFF write | List/create schools |
| GET/PATCH/DELETE | `/schools/{id}/` | read / OWNER,STAFF write | School detail + geofences summary |
| GET/POST | `/schools/{id}/classes/` | nested CRUD | Classes |
| GET/POST | `/schools/{id}/classes/{cid}/sections/` | nested CRUD | Sections |
| GET/POST/PATCH/DELETE | `/schools/students/` | CUSTOMER own / STAFF all | Students |

---

## Catalog

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| GET | `/catalog/categories/` | all | Category tree |
| POST/PATCH/DELETE | `/catalog/categories/` | OWNER,STAFF | Category CRUD |
| GET | `/catalog/products/` | all | Filter `category`, `type`, `q`, `school` (kit products ∪ `requires_school=False`), `include_inactive` (staff). Ordering: `ordering=` or `sort=` with `name\|-name\|base_price\|-base_price\|author\|-author\|popularity_score\|-popularity_score`. Variants included for OWNER/STAFF (or `include_variants=1`). Product fields include `author`, `publisher`, `mrp`, `base_price` (sale), computed `discount_percent`, `popularity_score` |
| GET | `/catalog/products/{id}/` | all | Product detail |
| GET | `/catalog/products/{id}/related/` | all | Curated `ProductRelation` first, then same-category fill; limit from storefront `related_limit` (default 8) |
| POST/PATCH/DELETE | `/catalog/products/` | OWNER,STAFF | Product CRUD |
| POST | `/catalog/products/bulk-import/` | OWNER,STAFF | Navneet dealer Excel bulk upsert (multipart). Fields: `file` (.xlsx required), `images_zip` (optional; image basename stem = CODE/SKU), `category` (optional UUID; else auto `Navneet Books`), `publisher` (default `Navneet`), `product_type` (default `BOOK`; stationery name heuristics), `tax_percent`, `dry_run`, `update_existing` (default true), `sheet` (optional sheet name). Idempotent on variant `sku`/`barcode` = CODE. Price col → `mrp` + `base_price`. Response: `{dry_run, mapping, summary, rows[]}`. Images optional — use `upload_image` later per product. |
| POST | `/catalog/products/{id}/upload_image/` | OWNER,STAFF | Multipart image |
| POST | `/catalog/products/{id}/variants/` | OWNER,STAFF | Add variant |
| GET | `/catalog/kits/` | all | Filter `school`, `school_class` |
| POST/PATCH/DELETE | `/catalog/kits/{id}/items/` | OWNER,STAFF | Kit line items |

### Navneet Excel column mapping

| Excel | Catalog field |
|-------|----------------|
| `CODE` | `ProductVariant.sku` (+ `barcode`) |
| `PRODUCT NAME` | `Product.name` |
| Price (col D; often unlabeled) | `Product.mrp` and `Product.base_price` (same at import) |
| — | `Product.publisher` default `Navneet` |
| — | `Product.product_type` default `BOOK` (stationery keywords → `STATIONERY`) |
| Sheets | `Sheet1` (header row), `Gujarati Mid` (headerless same layout); empty sheets ignored |

---

## CMS / Storefront

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| GET | `/cms/storefront-settings/` | public | Singleton settings: `default_catalog_view` (`grid`\|`list`), `home_delivery_fee`, `free_delivery_threshold` (null=off), SLA strings (`sla_local_copy`, `sla_default_copy`, `sla_disclaimer`), `share_message_template`, `share_base_url`, `related_strategy`, `related_limit`, contact phone/email/address |
| PATCH | `/cms/storefront-settings/` | OWNER,STAFF | Partial update settings (response includes `updated_at`) |
| GET | `/cms/stats/` | public | Published home stats (`label`, `value`, `sort_order`); OWNER/STAFF see unpublished too |
| CRUD | `/cms/stats/{id}/` | OWNER,STAFF write | Home stats |
| GET | `/cms/how-it-works/` | public | Published how-it-works steps |
| CRUD | `/cms/how-it-works/{id}/` | OWNER,STAFF write | Steps (`title`, `body`, `icon`, `sort_order`, `is_published`) |
| GET | `/cms/faq/` | public | Published FAQ items |
| CRUD | `/cms/faq/{id}/` | OWNER,STAFF write | FAQ (`question`, `answer`, `sort_order`, `is_published`) |
| GET | `/cms/pages/` | public | Published CMS pages (list omits `body`) |
| GET | `/cms/pages/{slug}/` | public | Published page detail by slug (unpublished → 404 for public) |
| CRUD | `/cms/pages/{slug}/` | OWNER,STAFF write | Pages (`slug`, `page_type`, `title`, `body`, `is_published`, `sort_order`). `page_type`: `about\|careers\|blog\|contact\|shipping\|returns\|refunds\|payments\|process\|account_delete\|privacy\|terms\|other` |
| GET | `/cms/pincode-estimate/?pincode=` | public | ETA: exact rule → longest prefix → SLA fallback. `{pincode, matched, source, min_days, max_days, label, sla_copy, sla_disclaimer}` |
| CRUD | `/cms/pincode-rules/` | OWNER,STAFF | Pincode rules (`pincode` and/or `pincode_prefix`, `min_days`, `max_days`, `label`, `sort_order`, `is_active`) |

Checkout (HOME): `delivery_fee = 0` when `subtotal >= free_delivery_threshold`; else `home_delivery_fee` from settings.

---

## Inventory

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| GET | `/inventory/stock/` | OWNER,STAFF,PARTNER read | Filter `warehouse`, `low_stock` |
| POST | `/inventory/adjustments/` | OWNER,STAFF | `{variant_id, quantity_delta, reason}` |
| GET | `/inventory/ledger/` | OWNER,STAFF | Audit log (paginated) |
| CRUD | `/inventory/suppliers/` | OWNER,STAFF | Suppliers |
| CRUD | `/inventory/purchase-orders/` | OWNER,STAFF | Purchase orders |
| POST | `/inventory/purchase-orders/{id}/receive/` | OWNER,STAFF | Receive stock; optional `{lines: [{line_id, quantity_received}]}` |

---

## Cart & Orders

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| GET | `/cart/` | CUSTOMER | Get cart |
| POST | `/cart/` | CUSTOMER | Add item `{variant, quantity, metadata?}` |
| PATCH | `/cart/{item_id}/` | CUSTOMER | Update item |
| DELETE | `/cart/{item_id}/` | CUSTOMER | Remove item |
| POST | `/orders/` | CUSTOMER | Checkout `{fulfillment_type, student_id?, address?, payment_method}` |
| POST | `/orders/pos/` | OWNER,STAFF | Walk-in POS `{lines[], discount?, payment_method, upi_reference?}` |
| GET | `/orders/` | role-filtered | Order list. Query: `status`, `school_id`, `created_after`, `created_before` (ISO date/datetime) |
| GET | `/orders/{id}/` | role-filtered | Order detail |
| PATCH | `/orders/{id}/status/` | OWNER,STAFF,PARTNER | `{status, note?}`. Customers must use cancel. |
| POST | `/orders/{id}/assign-partner/` | OWNER,STAFF | `{partner_id}` |
| GET | `/orders/{id}/suggested-partners/` | OWNER,STAFF | Partner suggestions |
| POST | `/orders/{id}/cancel/` | CUSTOMER (own) | Cancel before PACKING |

### Order Status Values

`PLACED`, `CONFIRMED`, `PACKING`, `PACKED`, `ASSIGNED`, `PICKED_UP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `SCHEDULED_FOR_SCHOOL`, `AT_SCHOOL`, `HANDED_TO_STUDENT`, `COMPLETED`, `CANCELLED`

---

## Delivery

| Method | Path | RBAC | Description |
|--------|------|------|-------------|
| POST | `/delivery/location/` | PARTNER | `{lat, lng, accuracy?, speed?, heading?}` |
| GET | `/delivery/partners/` | OWNER,STAFF | Fleet list + last location |
| PATCH | `/delivery/partners/{id}/duty/` | OWNER,STAFF | Admin override `{is_on_duty?, is_online?}` |
| GET | `/delivery/partners/{id}/location/` | OWNER,STAFF | Partner location |
| GET | `/delivery/orders/{order_id}/route/` | authenticated (order owner) | Cached route polyline |
| POST | `/delivery/geocode/` | CUSTOMER,OWNER,STAFF | `{line1?, line2?, city?, pincode?, lat?, lng?}` → `{lat, lng}` (PARTNER denied) |
| CRUD | `/delivery/geofences/` | OWNER,STAFF | GeoJSON polygon in `geojson` field |

---

## Payments & Receipts

| Method | Path | Description |
|--------|------|-------------|
| POST | `/payments/cashfree/create/` | `{order_id, return_url?}` → Cashfree order + `payment_session_id`. Optional `return_url` for web checkout (origin must be in `SCHOOLBAJAR_WEB_ORIGINS`; may include `{order_id}`). Flutter omits it. |
| POST | `/payments/cashfree/verify/` | Confirm order paid via Cashfree API |
| POST | `/payments/webhook/cashfree/` | Cashfree webhook (no auth) |
| POST | `/payments/cod/` | Confirm COD `{order_id}` |
| POST | `/payments/upi-manual/submit/` | Customer UPI ref (`upi_reference` required; optional multipart `proof_image`) |
| POST | `/payments/upi-manual/verify/` | STAFF verify UPI |
| POST | `/payments/pos/complete/` | OWNER,STAFF mark POS paid `{order_id}` |
| GET | `/receipts/` | List receipts |
| GET | `/receipts/{id}/download/` | PDF download |

---

## Notifications

| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications/` | List user notifications |
| PATCH | `/notifications/{id}/read/` | Mark read |

---

## Reports (OWNER only)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/reports/dashboard/` | Today's KPIs (OWNER) |
| GET | `/reports/store-dashboard/` | Store tiles (OWNER,STAFF) |
| GET | `/reports/sales/?from=&to=` | Sales by day |
| GET | `/reports/stock-valuation/` | Stock value |
| GET | `/reports/partner-performance/` | Partner stats |

---

## Desktop releases

Full flow, security model, and client notes: [DESKTOP_RELEASES.md](./DESKTOP_RELEASES.md).

**Preferred auto-update path** (OWNER/STAFF; JWT + app key; never put JWT in the query string):

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/desktop/releases/latest/` | IsAuthenticated | Update check — metadata only (`version`, `build_number`, `platforms.*.available`, no URLs/paths) |
| POST | `/desktop/releases/latest/download-ticket/` | OWNER,STAFF | Mint single-use download ticket (~90s TTL); body `{"platform":"windows"\|"macos"}` |
| GET | `/desktop/releases/latest/download/?platform=` | OWNER,STAFF | Consume ticket + stream installer (`X-Desktop-Download-Ticket` preferred; `ticket=` query fallback) |
| GET | `/desktop/releases/` | OWNER,STAFF | List recent releases |
| POST | `/desktop/releases/` | OWNER,STAFF | Publish release (multipart: `version`, optional `build_number`/`notes`, `windows_exe`/`macos_dmg`) |

Ticket mint and stream are rate-limited (~10/min/user → 429). CUSTOMER/PARTNER → 403.

**Legacy OTP download** (admin console / ops; do not use for auto-update):

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/desktop/releases/download-otp/` | OWNER,STAFF | Request in-app download OTP (5/min); optional `{"platform":...}` |
| POST | `/desktop/releases/download/` | OWNER,STAFF | Verify OTP + stream installer; body `{"otp","platform"}` |

---

## WebSocket Messages

**Auth (do not use `?token=<JWT>` — leaks in logs):**

1. Handshake headers: `Authorization: Bearer <access>` + `X-SchoolBajar-App-Key` (native)
2. First message (not logged): `{"type":"auth","token":"<access>","app_key":"<optional if configured>"}`
3. Short-lived ticket (website): `POST /api/v1/auth/ws-ticket/` with JWT (app key skipped when `Origin` is allowlisted) then connect `ws/v1/orders/{id}/?ticket=<opaque>` (single-use, ~60s TTL). Never put the access JWT in the query string.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/ws-ticket/` | Mint single-use WS ticket (JWT; app key required unless web Origin) |

### Channels

| Path | Group | Access |
|------|-------|--------|
| `/ws/v1/fleet/` | `fleet_admin` | OWNER, STAFF |
| `/ws/v1/orders/{order_id}/` | `order_{uuid}` | customer, partner, OWNER, STAFF |
| `/ws/v1/partner/` | `partner_{user_id}` | PARTNER self |

### Server → Client

**location_update**
```json
{
  "type": "location_update",
  "partner_id": "uuid",
  "order_id": "uuid|null",
  "lat": 23.0225,
  "lng": 72.5714,
  "heading": 90,
  "recorded_at": "2026-06-29T10:00:00+05:30"
}
```

**order_status**
```json
{
  "type": "order_status",
  "order_id": "uuid",
  "status": "OUT_FOR_DELIVERY",
  "message": "Your order is on the way"
}
```

**geofence_event**
```json
{
  "type": "geofence_event",
  "event": "ENTER",
  "geofence_name": "ABC School Gate",
  "order_id": "uuid"
}
```

### Client → Server (partner channel)

**location_ping**
```json
{
  "type": "location_ping",
  "lat": 23.02,
  "lng": 72.57,
  "accuracy": 12.5
}
```
