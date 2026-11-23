# Desktop app distribution (Windows .exe / macOS .dmg)

Desktop auto-update uses a **short-lived single-use download ticket** + authenticated
stream. Admin console can still use the legacy OTP download path.

## Endpoints (base `/api/v1/`, requires `X-SchoolBajar-App-Key`)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/desktop/releases/latest/` | IsAuthenticated | Update check (metadata only) |
| POST | `/desktop/releases/latest/download-ticket/` | OWNER/STAFF | Mint single-use download ticket (~90s TTL) |
| GET | `/desktop/releases/latest/download/` | OWNER/STAFF | Consume ticket + stream installer |
| GET | `/desktop/releases/` | OWNER/STAFF | List recent releases |
| POST | `/desktop/releases/` | OWNER/STAFF | Publish release (multipart) |
| POST | `/desktop/releases/download-otp/` | OWNER/STAFF | **Legacy** request download OTP (5/min) |
| POST | `/desktop/releases/download/` | OWNER/STAFF | **Legacy** verify OTP + stream installer |

## Auto-update security model

Preferred client flow for desktop auto-update (OWNER/STAFF sessions only):

1. Poll `GET /desktop/releases/latest/` (JWT + app-key). Compare `build_number` / `version`.
2. If newer: `POST /desktop/releases/latest/download-ticket/` with `{"platform":"windows"|"macos"}`.
3. `GET /desktop/releases/latest/download/?platform=...` with the ticket.
4. Save the attachment stream and install / relaunch.

### Controls

| Control | Behavior |
|---------|----------|
| AuthN | JWT `IsAuthenticated` + existing app-key middleware |
| AuthZ | Ticket mint + download: **OWNER/STAFF only** → 403 for CUSTOMER/PARTNER |
| Ticket | Opaque `token_urlsafe`; **hashed** in cache; TTL **90s**; **single-use** |
| Binding | Ticket bound to `user_id` + `platform` + `release_id` / `build_number` |
| Ticket transport | Prefer header `X-Desktop-Download-Ticket`. Query `ticket=` allowed as fallback. **Never put JWT in the query string.** |
| Platform | Allowlist `windows` \| `macos` only → 400 otherwise |
| Missing artifacts | 404 when no latest release or platform file absent; responses never leak storage paths |
| Rate limit | ~**10/min/user** on ticket mint **and** download → 429 `{detail, code: "throttled", wait?}` |
| Streaming | `Content-Disposition: attachment`; production may use `X-Accel-Redirect` / internal media |
| Audit | Success/fail logs include user id, role, platform, build_number — **no ticket/OTP/JWT** |
| Legacy OTP | `download-otp` / `download` remain for admin console; do not remove |

### Latest (desktop update check)

```http
GET /api/v1/desktop/releases/latest/
Authorization: Bearer <jwt>
X-SchoolBajar-App-Key: <app-key>
```

404 if nothing published. Success body (safe metadata only — no URLs or paths):

```json
{
  "version": "1.2.0",
  "build_number": 12,
  "released_at": "2026-08-12T07:53:00+00:00",
  "notes": "optional changelog",
  "platforms": {
    "windows": { "available": true, "filename": "SchoolBajar-Setup-1.2.0.exe", "size_bytes": 123 },
    "macos": { "available": true, "filename": "SchoolBajar-1.2.0.dmg", "size_bytes": 456 }
  }
}
```

Compare with local `build_number` (integer) or semver `version` string.

### Ticket mint

```http
POST /api/v1/desktop/releases/latest/download-ticket/
Authorization: Bearer <jwt>
Content-Type: application/json

{"platform":"windows"}
```

Success:

```json
{
  "ticket": "<opaque>",
  "expires_in": 90,
  "platform": "windows",
  "build_number": 12,
  "version": "1.2.0"
}
```

Errors: 400 bad platform, 403 wrong role, 404 no latest / missing platform file, 429 throttled.

### Ticket download (stream)

```http
GET /api/v1/desktop/releases/latest/download/?platform=windows
Authorization: Bearer <jwt>
X-Desktop-Download-Ticket: <opaque>
```

Fallback (ticket only in query — still send JWT in `Authorization`):

```http
GET /api/v1/desktop/releases/latest/download/?platform=windows&ticket=<opaque>
Authorization: Bearer <jwt>
```

Success: binary stream with `Content-Disposition: attachment; filename="..."`.

Errors: 400 invalid/expired/reused ticket or platform mismatch, 403 wrong role, 404 missing file, 429 throttled.

## Publish (admin)

```http
POST /api/v1/desktop/releases/
Content-Type: multipart/form-data

version=1.2.0
build_number=12          # optional; auto-increments if omitted
notes=Changelog text     # optional
windows_exe=<file.exe>   # optional but at least one file required
macos_dmg=<file.dmg>
```

Marks the new row as `is_latest` (previous latest cleared).

## Legacy download OTP flow (admin)

Kept for admin console / ops; **prefer ticket flow for auto-update**.

1. `POST /api/v1/desktop/releases/download-otp/` body optional `{"platform":"windows"|"macos"}`
   - Response: `{"expires_in": 300, "otp": "123456"}` for OWNER/STAFF (in-app; no SMS)
2. `POST /api/v1/desktop/releases/download/` body `{"otp":"123456","platform":"windows"|"macos"}`
   - Success: binary stream with `Content-Disposition: attachment; filename="..."`
   - OTP is one-time (hashed in cache, TTL 5 minutes)
   - 400 invalid/expired OTP, 404 platform file missing, 403 wrong role

`SCHOOLBAJAR_OTP_BYPASS_CODE` (non-empty, cleared in production) also works for legacy download verify, same as login OTP.

## Storage location

Files are stored under Django media:

```
MEDIA_ROOT/desktop/releases/<version>/<original-filename>
```

Example: `media/desktop/releases/1.2.0/SchoolBajar-Setup-1.2.0.exe`

`MEDIA_ROOT` defaults to `schoolbajar-backend/media/` (gitignored). In production, back this directory (or use object storage later).

Direct `/media/desktop/...` access is denied to non-OWNER/STAFF via the authenticated media gate.

## Env vars

```bash
# Max installer upload size (bytes). Default 524288000 (500 MiB).
SCHOOLBAJAR_DESKTOP_MAX_UPLOAD_BYTES=524288000

# Shared with login OTP — empty in production. Legacy download only.
# SCHOOLBAJAR_OTP_BYPASS_CODE=
```

`DATA_UPLOAD_MAX_MEMORY_SIZE` is raised to at least `SCHOOLBAJAR_DESKTOP_MAX_UPLOAD_BYTES` so large multipart publishes are accepted.

Throttle rate (settings): `desktop_latest_download` = `10/min` (ticket + stream); `desktop_download_otp` = `5/min` (legacy).

## Notes for client agents

**Desktop (Tauri / Flutter desktop):**

1. Poll `GET .../releases/latest/` on launch / periodically.
2. If remote `build_number` (or version) is newer and `platforms.<os>.available`, mint a ticket then GET download with `X-Desktop-Download-Ticket`.
3. Keep JWT in the `Authorization` header only; never append access tokens to the download URL.
4. Handle 403 (wrong role), 404 (artifact missing), 429 (back off), and ticket expiry (re-mint).
5. Do **not** use legacy OTP endpoints for auto-update.

**Admin Flutter:** OWNER/STAFF only. May keep OTP download for manual installs, or switch to the ticket flow. Publish remains multipart `POST .../releases/`.
