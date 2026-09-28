# Phase 4 Status — Responder/Admin Web Dashboard

Scope of this document: what the Phase 4 dashboard actually is, what was verified and how, and
what is explicitly not done. Labels follow `docs/ARCHITECTURE.md` §8.

Phase 4 was started only after the Phase 3 verification gate passed — see `docs/PHASE3_STATUS.md`.

---

## 1. What Phase 4 is

A browser dashboard for **responders and admins**, built as a pure client of the Phase 3 API.

- Location: `dashboard/`
- Stack: React 18 + TypeScript + Vite (no UI framework, no state library)
- Auth: the existing Sanctum bearer token from `POST /api/login` — no second auth system
- Transport: polling (`docs/ARCHITECTURE.md` §8: push notifications REQUIRE EXTERNAL SERVICE,
  "Phase 4 ships polling as the working fallback")

### Backend changes made for Phase 4

**None.** No migration, model, route, controller, service, enum or policy was added or edited.
The dashboard consumes the Phase 3 surface exactly as it already existed. This was the intended
outcome of reading the API spec first: §4 already specifies every endpoint the dashboard screens
need, including the two written specifically for it (`/dashboard/statistics`,
`/dashboard/active-alerts`).

Consequently there is no new alert table, user table, responder table, audit table, state enum or
authentication mechanism — none were duplicated because none were added.

---

## 2. Screens, and the endpoints each one uses

| Screen | Route | Endpoints | Roles |
| --- | --- | --- | --- |
| Sign-in | `/login` | `POST /api/login`, `GET /api/profile` | any (non-responder/admin is refused with an explanation) |
| Active Alerts (live board + counters) | `/` | `GET /api/dashboard/active-alerts`, `GET /api/dashboard/statistics`, `GET /api/schools` (admin only, for the school filter) | responder, admin |
| Alert detail (location, delivery, timeline, actions) | `/alerts/{id}` | `GET /api/alerts/{id}`, `POST .../acknowledge`, `.../respond`, `.../resolve`, `.../cancel` | responder, admin |
| Incident History (status/date filters, pagination) | `/history` | `GET /api/alerts` | responder, admin |
| Students & Staff roster | `/roster` | `GET /api/students` | responder, admin |
| Responders roster | `/responders` | `GET /api/responders` | admin only |

### Security posture

The dashboard treats the server as the only authority:

- `role` comes from `GET /api/profile` (the server's own user row), never from user input, and is
  used **only to decide what to render**. Every endpoint re-checks role, school scope and alert
  ownership server-side; hiding a nav link is a convenience, not a control.
- No `school_id`, `role`, `user_id`, `responder_id` or `status` is ever sent in a request body to
  influence authorization or ownership. The only bodies the dashboard sends are
  `{email, password}`, `{resolution_note}` and `{cancellation_reason}`.
- School isolation is not implemented client-side at all. A responder's own-school scoping is
  whatever the backend returns. The admin "school filter" is just the spec's optional
  `?school_id=` query parameter, which the backend ignores for responders.
- Action buttons follow the approved state machine (§1.4) exactly: no transition is offered that
  the backend would refuse, and none that it allows is hidden. A `409` (another responder won the
  race) is surfaced with the server's `current_status` and the view resyncs.
- `401` clears the stored token and returns to sign-in.

---

## 3. Verification — what was actually run

### IMPLEMENTED IN CODE and VERIFIED BY TEST (backend regression, re-run after Phase 4)

| Check | Result |
| --- | --- |
| `php artisan test` (SQLite, in-memory) | **29 passed (97 assertions)** |
| `php artisan test` against MariaDB 10.6 | **29 passed (97 assertions)** |

Unchanged from the Phase 3 gate, as expected — Phase 4 touched no backend file.

### IMPLEMENTED IN CODE and VERIFIED BY MANUAL BROWSER RUN

Run against the real Laravel app (`php artisan serve`) on a freshly migrated and seeded MariaDB
database, driving the actual UI in Chrome:

| Scenario | Result |
| --- | --- |
| Responder sign-in (`santos@example.edu`) | token stored, profile loaded, dashboard rendered |
| Live board + counters | 3 seeded alerts listed; counters 3/0/0/0 correct |
| `RECEIVED → ACKNOWLEDGED` from the UI | status, timeline entry and actor ("Mr. Santos") all updated |
| `ACKNOWLEDGED → RESPONDING` | button set changed correctly; timeline updated |
| `RESPONDING → RESOLVED` with a note | resolve button stayed disabled until a note was typed; note persisted and displayed |
| Closed incident | action buttons replaced by "no further transitions are possible" |
| Concurrent transition (alert acknowledged out-of-band by an admin via the API, then Acknowledge clicked in a stale UI) | `409` banner shown verbatim from the server, including `current_status`, and the view resynced to ACKNOWLEDGED |
| Incident History | correct rows, statuses, acknowledged-by/closed-by, duration, pagination counts |
| Students & Staff roster (as responder) | own-school roster only |
| Admin sign-in | extra "Responders" nav item and the all-schools filter appear |
| Responders roster (admin) | name/email/school/position/availability rendered |
| Location without a Maps key | coordinates + external map link shown, with the external-service dependency stated in the UI |

Screenshots of these runs were captured during verification.

### REQUIRES EXTERNAL SERVICE

| Item | Status |
| --- | --- |
| Google Maps embed on the alert detail page | Integration point is built (`VITE_GOOGLE_MAPS_API_KEY`). With no key, the page shows coordinates and an external map link. The embedded map itself has **never been rendered or verified** — no key was available. |
| Push notifications to the dashboard | **Not implemented.** Polling is the approved Phase 4 default. |

### NOT VERIFIED

- No automated frontend tests exist (no unit, component or E2E suite). All UI verification above
  was manual. This is the largest gap in Phase 4.
- No cross-browser testing: Chrome only.
- No responsive/mobile-viewport testing; the layout is CSS-grid based and will reflow, but that
  was not verified at small widths.
- No accessibility audit (keyboard navigation, screen reader, contrast).
- No load testing of the polling interval against many concurrent responders.
- Production CORS is untightened: the framework default is `allowed_origins: ['*']` for `api/*`.
  Bearer tokens (not cookies) make this materially safer than it looks, but the dashboard origin
  should be pinned before deployment.

### NOT IN PHASE 4 SCOPE

- WebSocket/live-push updates (§9 explicitly defers this).
- Admin CRUD for schools, students or responder provisioning beyond the read views — the only
  write endpoint in that area, `POST /api/admin/responders`, has no approved §4 request/response
  spec (see the note in `routes/api.php`), so no UI was invented for it.
- Audit-log viewing (§9: admin-only and not specified as a screen).
- Any change to the mobile app.

---

## 4. Carried-over items from Phase 3

Unchanged and still open:

- `laravel/framework ^11.0` resolves to a release with published security advisories; Composer's
  advisory block had to be disabled to install it. Upgrade to a patched release before production.
- `./vendor/bin/pint --test` fails on 17 pre-existing files (formatting only). Left alone to avoid
  a large unrelated diff.
- MySQL 8.x was never run; MariaDB 10.6 was.

---

## 5. Gate status

**Phase 4 dashboard: functionally complete and manually verified against a real backend; no
automated frontend tests.**

The Phase 3 regression suite passes unchanged on both SQLite and MariaDB.
