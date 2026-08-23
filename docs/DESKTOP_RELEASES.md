# Desktop app distribution (Windows .exe / macOS .dmg)

Admin app downloads installers via OTP. Desktop app polls latest version metadata
(no file download on the check).

## Endpoints (base `/api/v1/`, requires `X-SchoolBajar-App-Key`)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/desktop/releases/latest/` | IsAuthenticated | Update check (desktop app) |
| GET | `/desktop/releases/` | OWNER/STAFF | List recent releases |
| POST | `/desktop/releases/` | OWNER/STAFF | Publish release (multipart) |
| POST | `/desktop/releases/download-otp/` | OWNER/STAFF | Request download OTP (rate-limited 5/min) |
| POST | `/desktop/releases/download/` | OWNER/STAFF | Verify OTP + stream installer |

### Latest (desktop update check)

```http
GET /api/v1/desktop/releases/latest/
Authorization: Bearer <jwt>
```

404 if nothing published. Success body:

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

### Publish (admin)

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

### Download OTP flow (admin)

1. `POST /api/v1/desktop/releases/download-otp/` body optional `{"platform":"windows"|"macos"}`
   - Response: `{"expires_in": 300}` always
   - When `DEBUG=True`: also `"otp": "123456"` (for local/admin console)
2. `POST /api/v1/desktop/releases/download/` body `{"otp":"123456","platform":"windows"|"macos"}`
   - Success: binary stream with `Content-Disposition: attachment; filename="..."`
   - OTP is one-time (hashed in cache, TTL 5 minutes)
   - 400 invalid/expired OTP, 404 platform file missing, 403 wrong role

`SCHOOLBAJAR_OTP_BYPASS_CODE` (non-empty, cleared in production) also works for download verify, same as login OTP.

**OTP delivery (important for admin Flutter)**

There is **no SMS/email provider** for desktop download OTP yet.
Customer phone verification no longer uses OTP (trust-on-entry). Desktop installer download and any future staff SMS flows still use `apps.accounts.otp` / `apps.desktop.otp` cache helpers.

| Environment | How admin gets the code |
|-------------|-------------------------|
| `DEBUG=True` (local / staging with DEBUG) | Included in `download-otp` JSON as `otp` |
| Production (`DEBUG=False`) | Same gap as login OTP until SMS is wired; do **not** expect `otp` in the JSON. Wire SMS into `apps/desktop/otp.py` alongside `apps/accounts/otp.py`, or use a temporary secure ops path. Bypass code is forced empty in `production.py`. |

Admin Flutter should:

1. Call `download-otp`
2. If response contains `otp`, show it (or auto-fill) for DEBUG builds
3. Otherwise prompt the user to enter the OTP from the same channel as login OTP once SMS exists

## Storage location

Files are stored under Django media:

```
MEDIA_ROOT/desktop/releases/<version>/<original-filename>
```

Example: `media/desktop/releases/1.2.0/SchoolBajar-Setup-1.2.0.exe`

`MEDIA_ROOT` defaults to `schoolbajar-backend/media/` (gitignored). In production, back this directory (or use object storage later).

You can also place builds via the publish API from the admin app, or drop files through Django admin (`DesktopRelease`).

## Env vars

```bash
# Max installer upload size (bytes). Default 524288000 (500 MiB).
SCHOOLBAJAR_DESKTOP_MAX_UPLOAD_BYTES=524288000

# Shared with login OTP — empty in production.
# SCHOOLBAJAR_OTP_BYPASS_CODE=
```

`DATA_UPLOAD_MAX_MEMORY_SIZE` is raised to at least `SCHOOLBAJAR_DESKTOP_MAX_UPLOAD_BYTES` so large multipart publishes are accepted.

## Notes for client agents

**Desktop (Tauri / Flutter desktop):** poll `GET .../releases/latest/` on launch / periodically; if `build_number` (or version) is newer, prompt update. Do **not** use the OTP download endpoints from the desktop app for update checks — those are admin-gated. Shipping an update URL/UX for end users can be added later; current download path is OTP-gated for admin distribution only.

**Admin Flutter:** OWNER/STAFF only. Flow: list/publish releases; download = request OTP → enter OTP → POST download with `platform` → save stream as `.exe` / `.dmg`.
