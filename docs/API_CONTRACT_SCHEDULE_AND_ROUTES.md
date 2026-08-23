# API contract — delivery schedule & multi-stop routes

Timezone for all schedule windows: **Asia/Kolkata** (IST).  
Weekdays: Python `date.weekday()` — Monday=0 … Sunday=6. Defaults: Tue=1, Thu=3, Sat=5.

## Auth (customer OTP-free)

### `POST /api/v1/auth/register/`
Request: `{ "phone", "password", "full_name" }`  
- No OTP required for CUSTOMER registration.  
- Optional `otp` is ignored if sent (backward compatible).  
- Response: `{ user, access, refresh }` (201).

Login unchanged: `POST /api/v1/auth/login/` with phone + password.

---

## Delivery schedule

### Model `DeliveryScheduleSettings` (singleton)
```json
{
  "delivery_days": [1, 3, 5],
  "time_windows": [
    { "start": "10:00", "end": "13:00" },
    { "start": "16:00", "end": "19:00" }
  ],
  "timezone": "Asia/Kolkata",
  "updated_at": "ISO-8601"
}
```

### `GET /api/v1/delivery/schedule/`
Auth: any authenticated user. Returns settings above.

### `PATCH /api/v1/delivery/schedule/`
Auth: OWNER / STAFF. Body: partial `{ delivery_days?, time_windows? }`.

### `GET /api/v1/delivery/schedule/slots/?days=14`
Auth: any authenticated user. Upcoming bookable slots:
```json
{
  "timezone": "Asia/Kolkata",
  "slots": [
    {
      "date": "2026-08-25",
      "weekday": 1,
      "window": { "start": "10:00", "end": "13:00" },
      "label": "Tue 25 Aug · 10:00–13:00"
    }
  ]
}
```

### Checkout slot
`POST /api/v1/orders/` may include optional:
```json
"delivery_slot": { "date": "YYYY-MM-DD", "start": "HH:MM", "end": "HH:MM" }
```
Validated against current schedule (HOME fulfillment). Stored on `Order.delivery_slot`.

---

## Multi-stop delivery routes

### Models
- `DeliveryRoute`: partner, status (`PENDING|ACTIVE|COMPLETED`), polyline, distance/duration, optimizer (`GOOGLE|HEURISTIC`)
- `DeliveryRouteStop`: route, order, sequence, lat/lng, address_label, status (`PENDING|ACTIVE|ARRIVED|COMPLETED|SKIPPED`)

### `POST /api/v1/delivery/routes/optimize/`
Auth: PARTNER (own) or OWNER/STAFF (`partner_id` required for staff).  
Builds/rebuilds optimized stop order from partner’s open assignments (ASSIGNED→OUT_FOR_DELIVERY).  
Uses Google Directions waypoint optimization when `SCHOOLBAJAR_GOOGLE_MAPS_SERVER_KEY` is set; else nearest-neighbor heuristic.

### `GET /api/v1/delivery/routes/active/?partner_id=`
Partner: own active/pending route. Staff: optional `partner_id`.

### `GET /api/v1/delivery/routes/{id}/`

### `POST /api/v1/delivery/routes/{id}/stops/{stop_id}/arrive/`
Marks stop ARRIVED (sets route ACTIVE if needed).

### `POST /api/v1/delivery/routes/{id}/stops/{stop_id}/complete/`
Marks stop COMPLETED; advances next stop to ACTIVE; may transition order to DELIVERED when appropriate.

Response shape (route):
```json
{
  "id": "uuid",
  "partner_id": "uuid",
  "status": "ACTIVE",
  "optimizer": "GOOGLE",
  "encoded_polyline": "...",
  "distance_meters": 12345,
  "duration_seconds": 3600,
  "stops": [
    {
      "id": "uuid",
      "order_id": "uuid",
      "order_number": "SM-...",
      "sequence": 1,
      "lat": 23.0,
      "lng": 72.5,
      "address_label": "...",
      "status": "ACTIVE"
    }
  ]
}
```

Existing `GET /api/v1/delivery/orders/{order_id}/route/` (per-order RouteCache) remains for single-leg ETA.

### WebSocket
- `location_update` — still on `fleet_admin`, `partner_{id}`, and **each** assigned order channel for that partner’s active stops (not only `current_order`).
- `route_update` — `{ type, route }` to `fleet_admin` + `partner_{id}` when route is optimized or stop status changes.

---

## Notifications
Order status transitions continue to create in-app + FCM (stub-log when Firebase creds missing).  
Assignment also notifies the partner. Device token: `POST /api/v1/auth/device-token/`.
