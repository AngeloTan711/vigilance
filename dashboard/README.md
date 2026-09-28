# VIGILANCE Dashboard (Phase 4)

Responder/admin web dashboard. A pure client of the Phase 3 API — it adds no tables, no
endpoints and no second authentication mechanism. See `../docs/PHASE4_STATUS.md` for verified
status and known gaps.

## Run it

```bash
# 1. Backend (from ../backend)
php artisan migrate:fresh --seed
php artisan serve --host=127.0.0.1 --port=8000

# 2. Dashboard
cp .env.example .env
npm install
npm run dev          # http://localhost:5173
```

`.env` defaults to `VITE_API_BASE_URL=/api`, which goes through the Vite dev proxy to
`http://127.0.0.1:8000`. For a deployed build, set `VITE_API_BASE_URL` to the API's absolute URL
instead.

Seeded logins (`../backend/database/seeders/DatabaseSeeder.php`), all with `password123`:

| Account | Role |
| --- | --- |
| `santos@example.edu` | responder (Sample High School) |
| `admin@example.edu` | admin |
| `jane.doe@example.edu` | student — cannot use the dashboard, by design |

## Build

```bash
npm run build        # tsc -b && vite build → dist/
```

## Configuration

| Variable | Purpose |
| --- | --- |
| `VITE_API_BASE_URL` | API base. `/api` (proxy) in dev, absolute URL in production. |
| `VITE_POLL_INTERVAL_MS` | Active-alert poll interval, default 10000. |
| `VITE_GOOGLE_MAPS_API_KEY` | Optional. Without it the alert page shows coordinates and an external map link instead of an embedded map. |

## Layout

```
src/
  api/client.ts       fetch wrapper: bearer token, 401 handling, ApiError carrying
                      the backend's {message, errors, current_status} envelope
  api/types.ts        the Phase 3 contract, mirrored — no invented states or roles
  auth/AuthContext    login/logout/profile; role is read from the server, used only
                      to decide what to render
  hooks/usePolling    polls while the tab is visible, refreshes on focus
  pages/              one file per screen
  components/         AlertCard, AlertActions (state-machine-driven), StatusBadge,
                      ErrorBanner, Layout
```

## Deployment note

The backend's CORS config is the framework default (`allowed_origins: ['*']` for `api/*`). The
dashboard authenticates with bearer tokens rather than cookies, but the origin should still be
pinned to the deployed dashboard before production.
