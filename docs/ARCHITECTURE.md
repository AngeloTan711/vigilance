# VIGILANCE — Phase 1 (Revised): Architecture, Schema, State Machine, API Spec, Screen Map

This revision replaces the Phase 1 document. Sections 1–2 (system diagram) and the Flutter/React
structure maps from v1 are unchanged and not repeated in full; everything below is new or
corrected.

---

## 1. Emergency Alert Status State Machine

### 1.1 States

```
ACTIVE → RECEIVED → ACKNOWLEDGED → RESPONDING → RESOLVED
```

`CANCELLED` is a terminal state reachable from `ACTIVE`, `RECEIVED`, or `ACKNOWLEDGED` only
(rules in 1.3).

### 1.2 State diagram

```
        ┌────────┐
        │ ACTIVE │ (created on-device, may not have reached server yet)
        └───┬────┘
            │ backend receives payload
            ▼
        ┌──────────┐
        │ RECEIVED │
        └───┬──────┘
            │ responder acknowledges
            ▼
        ┌──────────────┐
        │ ACKNOWLEDGED │
        └───┬───────────┘
            │ responder marks responding
            ▼
        ┌────────────┐
        │ RESPONDING │
        └───┬────────┘
            │ responder confirms resolution
            ▼
        ┌──────────┐
        │ RESOLVED │  (terminal)
        └──────────┘

CANCELLED is reachable from ACTIVE, RECEIVED, or ACKNOWLEDGED only — see 1.3.
No transition skips a state. RESPONDING cannot be cancelled (a responder is
already physically engaged; cancellation at that point must go through
RESOLVED with a note, not CANCELLED, so there is always a resolution record
for an incident someone responded to in person).
```

No backward transitions are permitted (e.g. `RESPONDING` cannot revert to `ACKNOWLEDGED`). If a
responder makes a mistake, that is a `CANCELLED` (before responding) or a `RESOLVED` with an
audit note (after responding) — history is never silently rewritten.

### 1.3 CANCELLED — who, when, why

Allowed from: `ACTIVE`, `RECEIVED`, `ACKNOWLEDGED`.
Not allowed from: `RESPONDING`, `RESOLVED`, `CANCELLED`.

Authorized to cancel:
- **The alerting student/staff user themselves** — only while status is `ACTIVE` or `RECEIVED`
  (i.e. before any responder has acknowledged). This covers accidental Pulse triggers. Once a
  responder has acknowledged, the *user* can no longer unilaterally cancel — a false alarm at
  that point is closed by the **responder**, not the student, so there's always a human
  confirmation on record.
- **A responder or admin at the alert's school** — from `ACTIVE`, `RECEIVED`, or `ACKNOWLEDGED`
  (e.g. confirmed false alarm, duplicate alert, test alert mistakenly left un-flagged).
- **Admin** — same as responder, any school.

A `CANCELLED` alert always requires a `cancellation_reason` (new column, see 1.5) — cancellation
without a reason is rejected by validation. This is a real emergency-safety system; a silent
cancel button is not acceptable.

### 1.4 Transition table

| Transition | Triggered by | Endpoint | DB fields updated | Timestamp | Audit log | Notification |
|---|---|---|---|---|---|---|
| (create) → `ACTIVE` | student/staff (mobile, on-device) | *(local only — no endpoint yet)* | local record only | `activated_at` | *(local, synced later)* | none yet |
| `ACTIVE` → `RECEIVED` | backend, automatically, on successful ingest | `POST /alerts` | `status`, all alert columns from payload | `received_at` | `alert_received` | push to responders of that school + confirmation to mobile app |
| `RECEIVED` → `ACKNOWLEDGED` | responder (own school) | `POST /alerts/{id}/acknowledge` | `status`, `acknowledged_by` (new column, see 1.5) | `acknowledged_at` | `alert_acknowledged` | discreet status push to mobile app |
| `ACKNOWLEDGED` → `RESPONDING` | responder who acknowledged, or another responder at same school | `POST /alerts/{id}/respond` | `status`, `responded_by` (new column) | `responded_at` | `alert_responding` | discreet status push to mobile app |
| `RESPONDING` → `RESOLVED` | responder (own school) or admin | `POST /alerts/{id}/resolve` | `status`, `resolved_by` (new column), `resolution_note` (new column) | `resolved_at` | `alert_resolved` | discreet status push to mobile app |
| `ACTIVE`/`RECEIVED` → `CANCELLED` | the alerting user | `POST /alerts/{id}/cancel` | `status`, `cancelled_by`, `cancellation_reason` (new columns) | `cancelled_at` (new column) | `alert_cancelled_by_user` | responders of that school notified it was cancelled |
| `ACTIVE`/`RECEIVED`/`ACKNOWLEDGED` → `CANCELLED` | responder/admin (own school) | `POST /alerts/{id}/cancel` | same as above | `cancelled_at` | `alert_cancelled_by_responder` | mobile app notified (discreetly) |

Every endpoint above re-validates the *current* status server-side before applying a transition
(e.g. `POST /alerts/{id}/respond` returns `409 Conflict` if the alert is not currently
`ACKNOWLEDGED`) — the frontend button being visible is not treated as authorization.

### 1.5 New columns required (added to `emergency_alerts`)

```sql
ALTER TABLE emergency_alerts
    ADD COLUMN acknowledged_by BIGINT UNSIGNED NULL,
    ADD COLUMN responded_by BIGINT UNSIGNED NULL,
    ADD COLUMN resolved_by BIGINT UNSIGNED NULL,
    ADD COLUMN cancelled_by BIGINT UNSIGNED NULL,
    ADD COLUMN cancelled_at DATETIME NULL,
    ADD COLUMN cancellation_reason VARCHAR(255) NULL,
    ADD COLUMN resolution_note VARCHAR(255) NULL,
    ADD CONSTRAINT fk_ack_by FOREIGN KEY (acknowledged_by) REFERENCES users(id),
    ADD CONSTRAINT fk_resp_by FOREIGN KEY (responded_by) REFERENCES users(id),
    ADD CONSTRAINT fk_resolved_by FOREIGN KEY (resolved_by) REFERENCES users(id),
    ADD CONSTRAINT fk_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES users(id);

ALTER TABLE emergency_alerts
    MODIFY COLUMN status ENUM('ACTIVE','RECEIVED','ACKNOWLEDGED','RESPONDING','RESOLVED','CANCELLED')
    NOT NULL DEFAULT 'ACTIVE';
```

These were missing from v1 — without `acknowledged_by`/`responded_by`/`resolved_by`, the system
could not show "who is handling this" on the dashboard or in incident history, which the spec's
own Incident History screen (§15) requires.

---

## 2. `communication_method` — redesigned

### 2.1 Problem with v1

v1's `communication_method ENUM('CLOUD','SMS')` cannot represent an alert that is created
on-device while offline and queued for later delivery — it isn't CLOUD (hasn't reached the
server yet) and it isn't SMS (SMS may not be attempted, or may itself fail). Forcing it into one
of those two values would misrepresent how the alert actually got there, which matters for an
incident record that responders and administrators rely on.

### 2.2 Final design: two separate fields

**`delivery_method`** — *how the alert is currently being attempted/was delivered*:
```
PENDING    -- created locally, no delivery attempt has succeeded yet
CLOUD      -- delivered via the Laravel API over internet
SMS        -- delivered via SMS fallback
```

**`delivery_status`** — *the state of that delivery attempt*:
```
QUEUED       -- stored locally, waiting for connectivity (device is offline)
SENDING      -- attempt in progress
DELIVERED    -- confirmed received by backend (sets received_at) or SMS confirmed sent
FAILED       -- attempt failed, will retry
```

A single alert's delivery history is not a single fixed value — it can legitimately try CLOUD,
fail, fall back to SMS, and later, once the SMS gateway confirms, or once connectivity returns
and the queued record syncs, resolve to `DELIVERED`. Rather than lose that history, a lightweight
`alert_delivery_attempts` table is added:

```sql
CREATE TABLE alert_delivery_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    emergency_alert_id BIGINT UNSIGNED NOT NULL,   -- nullable local alert id maps in after sync
    method ENUM('CLOUD','SMS') NOT NULL,
    status ENUM('SENDING','DELIVERED','FAILED') NOT NULL,
    attempted_at DATETIME NOT NULL,
    error_message VARCHAR(255) NULL,
    FOREIGN KEY (emergency_alert_id) REFERENCES emergency_alerts(id) ON DELETE CASCADE
);
```

`emergency_alerts.delivery_method` and `.delivery_status` always reflect the **current/most
recent** state (cheap to query for the dashboard); `alert_delivery_attempts` holds the full
history (useful for debugging a flaky connectivity incident, and for the audit trail). This
replaces the single `communication_method` column from v1.

### 2.3 Updated relevant column set

```sql
ALTER TABLE emergency_alerts
    DROP COLUMN communication_method,
    ADD COLUMN delivery_method ENUM('PENDING','CLOUD','SMS') NOT NULL DEFAULT 'PENDING',
    ADD COLUMN delivery_status ENUM('QUEUED','SENDING','DELIVERED','FAILED') NOT NULL DEFAULT 'QUEUED';
```

The local-only, pre-sync state (device offline, alert not yet on the server at all) is
represented entirely on-device (SQLite/Hive local queue) as `delivery_status = QUEUED`; once it
reaches the backend via `POST /alerts` (whether that POST happened immediately or after
reconnection), the server sets `delivery_status = DELIVERED`, `delivery_method` to whatever
actually got it there, and `received_at`.

---

## 3. Background Gesture Detection — corrected claims

v1 stated the detection service would run as an app-level singleton implying it survives
backgrounding. That is not accurate as a blanket claim and is corrected here.

### 3.1 What is actually possible, by app state

| App state | Gesture detection feasibility |
|---|---|
| App open, foreground | **Reliable.** Sensor stream (accelerometer/gyroscope) is read directly by the Flutter app process; no OS restriction applies. |
| App minimized (backgrounded, not killed), screen on | **Possible but constrained**, and requires a persistent **Android foreground service** (with a visible, low-priority notification — Android requires this for any background sensor/location work since Android 8+, tightened further in Android 12+/14). Without a foreground service, Android will throttle or kill sensor listeners within seconds to minutes depending on OEM battery management (this varies significantly by manufacturer — Samsung, Xiaomi, and others impose additional restrictions beyond stock Android). |
| Screen locked | **Not reliably possible for continuous motion-gesture sensing** on stock Android without a foreground service, and even with one, OEM-specific battery optimization (Doze mode, app standby buckets) can still suspend it. This must be tested per-device; it cannot be claimed to work universally. |
| App force-closed by user or OS | **Not possible.** No app code runs. This is an OS/Android limitation, not something any implementation can work around. |

### 3.2 First implementation scope (Phase 2)

Phase 2 will implement:
- Foreground gesture detection (app open) — this is the reliably-working baseline and is what
  "TEST PULSE" and "TEST EMERGENCY" exercise.
- The `GestureDetectionService` abstraction, structured so a background-capable implementation
  can be substituted later without changing the calling code (screens/providers depend on an
  interface, not a concrete implementation).
- An Android **foreground service** with the required persistent notification, to extend
  detection to "app minimized, screen on" — implemented, but explicitly labeled as
  `REQUIRES DEVICE TESTING` (see §8) because Doze/OEM battery restrictions cannot be verified
  from this environment and vary by phone.
- Locked-screen detection is **not** claimed as working in Phase 2. If it's needed, it is called
  out as a later phase requiring dedicated device testing across OEMs, and is not part of the
  MVP success criteria unless you confirm you want to scope it in.

This directly affects the "PROTECTION ACTIVE" screen's claims — it will say what's actually true
("Pulse monitoring active while app is open" in Phase 2), not imply lock-screen coverage that
hasn't been built and tested yet.

---

## 4. Full API Specification

Base URL: `/api`. All responses are JSON. Auth: `Authorization: Bearer <token>` (Laravel
Sanctum), except `login`/`register`. Every mutating endpoint re-validates role **and** school
scope server-side — a responder token for School A can never act on School B's alerts, regardless
of what the frontend sends.

Common error shape:
```json
{ "message": "string", "errors": { "field_name": ["validation message"] } }
```

---

### POST /api/login
- Auth required: No
- Roles: any
- Request:
```json
{ "email": "student@school.edu", "password": "string" }
```
- Validation: `email` required, valid email; `password` required, string.
- Success: `200 OK`
```json
{ "token": "1|abcdef...", "user": { "id": 12, "name": "Jane Doe", "role": "student", "school_id": 4 } }
```
- Errors: `422` (validation), `401` (`{"message":"Invalid credentials"}`)
- DB changes: creates a row in `personal_access_tokens` (Sanctum).
- Audit log: `login_success` / `login_failed` (user_id null on failure if email unknown).

---

### POST /api/register
- Auth required: No
- Roles: student, staff self-registration only (`responder`/`admin` cannot self-register — see
  §5)
- Request:
```json
{
  "name": "Jane Doe",
  "school_id_number": "S12345",
  "email": "jane@school.edu",
  "phone": "+639171234567",
  "password": "string",
  "password_confirmation": "string",
  "school_id": 4,
  "role": "student"
}
```
- Validation: `name` required string max 255; `email` required, valid, unique in `users`;
  `phone` required, valid phone format; `password` required, min 8, confirmed;
  `school_id` required, must exist in `schools`; `role` required, in `[student, staff]` only
  (server rejects `responder`/`admin` here regardless of what's submitted).
- Success: `201 Created`, same body shape as login (auto-login per §screen-3).
- Errors: `422` validation (incl. duplicate email).
- DB changes: insert into `users` (`status = active`).
- Audit log: `user_registered`.

---

### POST /api/logout
- Auth required: Yes
- Roles: any
- Request: none
- Success: `200 OK` `{ "message": "Logged out" }`
- DB changes: revokes current Sanctum token.
- Audit log: `logout`.

---

### GET /api/profile
- Auth required: Yes — Roles: any (own profile only)
- Success: `200 OK` — full user object minus `password`.
- Errors: `401` if token invalid/expired.

### PUT /api/profile
- Auth required: Yes — Roles: any (own profile only)
- Request: any subset of `{ name, phone, email }` (role/school_id are not user-editable)
- Validation: `email` unique except self; `phone` valid format.
- Success: `200 OK`, updated user object.
- Errors: `422` validation.
- Audit log: `profile_updated`.

---

### GET /api/emergency-contacts
- Auth required: Yes — Roles: any (own contacts only)
- Success: `200 OK`, array of contacts ordered by `priority`.

### POST /api/emergency-contacts
- Auth required: Yes — Roles: any
- Request:
```json
{ "name": "Maria Doe", "phone": "+639171234567", "relationship": "Mother", "priority": 1 }
```
- Validation: `name` required; `phone` required valid; `relationship` optional string;
  `priority` required integer ≥ 1, unique per user (server reassigns/rejects duplicate priority
  per user, documented choice: **reject** with `422` — the client must not silently reorder
  contacts behind the user's back).
- Success: `201 Created`, contact object.
- Errors: `422`.
- DB changes: insert into `emergency_contacts`.

### PUT /api/emergency-contacts/{id}
- Auth required: Yes — Roles: any, must own the contact (`403` otherwise)
- Request/validation: same fields as POST, all optional (partial update).
- Success: `200 OK`, updated contact.
- Errors: `403` (not owner), `404` (not found), `422` (validation).

### DELETE /api/emergency-contacts/{id}
- Auth required: Yes — Roles: any, must own the contact
- Success: `204 No Content`
- Errors: `403`, `404`.
- DB changes: hard delete (contacts are not sensitive incident records; soft-delete policy in
  §16 applies to `users`, not this table).

---

### POST /api/alerts
- Auth required: Yes — Roles: student, staff
- Request:
```json
{
  "latitude": 11.2449,
  "longitude": 125.0037,
  "accuracy": 10.5,
  "activated_at": "2026-09-25T19:30:00Z",
  "delivery_method": "CLOUD",
  "message": "Emergency assistance requested.",
  "is_test": false
}
```
- Validation: `latitude`/`longitude` required, numeric, in valid ranges (or both null if GPS
  genuinely unavailable — see note below); `accuracy` numeric nullable; `activated_at` required,
  ISO 8601, not in the future; `delivery_method` required, in `[CLOUD, SMS]` (this endpoint is
  only reached once a method succeeded — `PENDING`/`QUEUED` states never leave the device);
  `is_test` boolean, defaults false.
  - Note: GPS may legitimately be unavailable (indoors, permission denied). The payload allows
    null coordinates; the dashboard must render "Location unavailable" rather than assume GPS
    always succeeds — this was implicit in v1 and is made explicit here.
- Success: `201 Created`
```json
{ "id": 1042, "status": "RECEIVED", "received_at": "2026-09-25T19:30:04Z" }
```
- Errors: `422` validation, `401` unauthenticated.
- DB changes: insert `emergency_alerts` (`status=RECEIVED`, `received_at=now()`,
  `delivery_status=DELIVERED`); insert `alert_delivery_attempts` row.
- Audit log: `alert_received`.
- Notification: push to all responders where `responders.school_id = user.school_id`.
- Rate limiting: this endpoint is exempt from normal API rate limits (an emergency must never be
  throttled), but is monitored — repeated non-test alerts from the same user in a short window
  are flagged in `audit_logs` for admin review rather than blocked.

---

### GET /api/alerts
- Auth required: Yes — Roles: responder (own school only), admin (all schools; `?school_id=`
  optional filter)
- Query params: `status`, `include_test` (default `false` — test alerts excluded unless
  explicitly requested), `from`, `to`
- Success: `200 OK`, paginated array of alert summary objects.
- Errors: `403` if a responder tries `?school_id=` for a different school.

### GET /api/alerts/{id}
- Auth required: Yes — Roles: responder/admin (own school), or the alerting user themself
- Success: `200 OK`, full alert object including current `status`, `delivery_method`,
  `delivery_status`, all timestamp fields, `acknowledged_by`/`responded_by`/`resolved_by` (each
  expanded to `{id, name}`), and coordinates.
- Errors: `403` (wrong school / not the owner), `404`.

---

### POST /api/alerts/{id}/acknowledge
- Auth required: Yes — Roles: responder (own school)
- Preconditions: current `status` must be `RECEIVED` (`409 Conflict` otherwise, with the current
  status in the body so the dashboard can resync).
- Request: none required; optional `{}`.
- Success: `200 OK`, updated alert object.
- Errors: `403` (wrong school), `404`, `409` (wrong current status).
- DB changes: `status=ACKNOWLEDGED`, `acknowledged_at=now()`, `acknowledged_by=<responder user id>`.
- Audit log: `alert_acknowledged` (alert_id, user_id, ip_address).
- Notification: discreet push to the alerting student's device (per Cloak Mode wording, §9/§10).

### POST /api/alerts/{id}/respond
- Auth required: Yes — Roles: responder (own school)
- Preconditions: current `status` must be `ACKNOWLEDGED` (`409` otherwise).
- Success: `200 OK`, updated alert.
- Errors: `403`, `404`, `409`.
- DB changes: `status=RESPONDING`, `responded_at=now()`, `responded_by=<user id>`.
- Audit log: `alert_responding`.
- Notification: discreet push ("Response Team Responding").

### POST /api/alerts/{id}/resolve
- Auth required: Yes — Roles: responder (own school), admin
- Preconditions: current `status` must be `RESPONDING` (`409` otherwise).
- Request:
```json
{ "resolution_note": "Student located, met by school nurse. False alarm — accidental trigger." }
```
- Validation: `resolution_note` required, string max 255 (never silently resolved with no
  record).
- Success: `200 OK`, updated alert.
- Errors: `403`, `404`, `409`, `422` (missing note).
- DB changes: `status=RESOLVED`, `resolved_at=now()`, `resolved_by=<user id>`, `resolution_note`.
- Audit log: `alert_resolved`.
- Notification: discreet push ("Response Complete").

### POST /api/alerts/{id}/cancel
- Auth required: Yes — Roles: the alerting user (only while `ACTIVE`/`RECEIVED`), or
  responder/admin of that school (while `ACTIVE`/`RECEIVED`/`ACKNOWLEDGED`)
- Request:
```json
{ "cancellation_reason": "Accidental trigger while charging phone." }
```
- Validation: `cancellation_reason` required, string max 255.
- Success: `200 OK`, updated alert.
- Errors: `403` (role/state not permitted — e.g. student trying to cancel after
  `ACKNOWLEDGED`), `404`, `409` (status is `RESPONDING`/`RESOLVED`/already `CANCELLED`), `422`.
- DB changes: `status=CANCELLED`, `cancelled_at=now()`, `cancelled_by`, `cancellation_reason`.
- Audit log: `alert_cancelled_by_user` or `alert_cancelled_by_responder` (distinguished, per
  §1.4).
- Notification: the other party (responders if user cancelled; the mobile user if responder
  cancelled) is notified.

---

### GET /api/responders
- Auth required: Yes — Roles: admin
- Success: `200 OK`, array of `{ responder record, user: {id, name, email}, school }`.

### GET /api/students
- Auth required: Yes — Roles: responder (own school), admin
- Query: `?role=student,staff` (dashboard's "Students" page may want staff too)
- Success: `200 OK`, paginated array, scoped to school for responders.

### GET /api/schools
- Auth required: Yes — Roles: admin
- Success: `200 OK`, array of schools.

### GET /api/dashboard/statistics
- Auth required: Yes — Roles: responder (own school), admin
- Success: `200 OK`
```json
{ "active": 2, "acknowledged": 1, "responding": 1, "resolved_today": 12 }
```
- Note: excludes `is_test=true` alerts from all counts by default.

### GET /api/dashboard/active-alerts
- Auth required: Yes — Roles: responder (own school), admin
- Success: `200 OK`, array of alerts with `status IN (RECEIVED, ACKNOWLEDGED, RESPONDING)`,
  `is_test=false` unless `?include_test=1`.

---

## 5. Responder Enforcement (users ↔ responders)

A "responder" is enforced as **both** `users.role = 'responder'` **and** a matching row in
`responders` — neither alone is sufficient. This is deliberate: `role` controls what the
Sanctum/middleware layer allows the account to *do* (route access), while the `responders` row
carries operational data (which school, position, availability) that doesn't belong on `users`
and that an admin manages independently of the account itself.

Enforcement points:

1. **Account creation is admin-only.** There is no public registration path to `role=responder`
   (see `POST /register` validation above — it hard-rejects `responder`/`admin`). Responder
   accounts are created via an admin-only endpoint (`POST /api/admin/responders`, added to the
   admin route group in Phase 3) that, in a single transaction:
   - creates the `users` row with `role = 'responder'`, or promotes an existing `staff` user, and
   - creates the matching `responders` row (`school_id`, `position`, `is_available = true`).
   Both inserts happen in one DB transaction — a `users.role='responder'` row without a
   `responders` row (or vice versa) should never exist. A Laravel model observer/service class
   (`ResponderProvisioningService`) is the single place this pairing is created, so it can't be
   bypassed by a different code path later.

2. **Route middleware checks `role`** (`role:responder`) for coarse access control (can this
   token even hit `/alerts/{id}/acknowledge`).

3. **The controller/service layer additionally loads the `responders` row** for the authenticated
   user and checks `responders.school_id` against the alert's `school_id` for the actual
   authorization decision (can *this* responder act on *this* alert). If `role=responder` but no
   `responders` row exists (a data-integrity problem, since step 1 should prevent it), the
   request is rejected with `403` and an `audit_logs` entry `responder_record_missing` is
   written — this is treated as an integrity error to investigate, not a silent pass-through.

4. **`is_available`** is informational for the dashboard's responder-roster view in Phase 1
   scope; it does not currently block `/acknowledge` (an "unavailable" responder covering an
   emergency should still be able to act) — flagged as a deliberate scope decision, revisit if
   you want availability to be enforced rather than advisory.

---

## 6. Permission Matrix

✅ = allowed  ❌ = not allowed  🔶 = allowed with scope restriction (noted)

| Action | STUDENT | STAFF | RESPONDER | ADMIN |
|---|---|---|---|---|
| Login | ✅ | ✅ | ✅ | ✅ |
| Self-registration | ✅ | ✅ | ❌ (admin-provisioned only) | ❌ (admin-provisioned only) |
| Edit own profile | ✅ | ✅ | ✅ | ✅ |
| Manage own emergency contacts | ✅ | ✅ | 🔶 not applicable to role duties, but allowed as a user | 🔶 same |
| Create emergency alert | ✅ | ✅ | 🔶 yes, as any user can (staff-as-responder duality, §Staff) | 🔶 same |
| View own alert(s) | ✅ | ✅ | ✅ | ✅ |
| View other users' alerts | ❌ | ❌ | 🔶 own school only | ✅ all schools |
| Acknowledge alert | ❌ | ❌ | 🔶 own school only | ✅ (admin override) |
| Respond to alert | ❌ | ❌ | 🔶 own school only | ✅ (admin override) |
| Resolve alert | ❌ | ❌ | 🔶 own school only | ✅ |
| Cancel own alert (pre-ack) | ✅ | ✅ | ✅ (their own) | ✅ (their own) |
| Cancel any alert (own school) | ❌ | ❌ | ✅ | ✅ (any school) |
| View student/staff roster | ❌ | ❌ | 🔶 own school only | ✅ all schools |
| Manage responders (create/deactivate) | ❌ | ❌ | ❌ | ✅ |
| Manage schools | ❌ | ❌ | ❌ | ✅ |
| Manage users (deactivate, role changes) | ❌ | ❌ | ❌ | ✅ |
| View audit logs | ❌ | ❌ | ❌ (not in Phase 1 scope) | ✅ |
| View incident history | 🔶 own incidents only | 🔶 own incidents only | 🔶 own school | ✅ all |

Note on STAFF acting as a responder: the spec (§Staff) says staff "may also be configured as an
authorized responder if assigned that role" — this means a staff member given `role=responder`
**becomes** a responder account per §5 above (with its own `responders` row); it is not a
separate "staff can also acknowledge" permission bolted onto the `staff` role. A person is either
a student/staff account (can only trigger/manage their own alerts) or a responder account (can
act on others' alerts) — never both at once under one role value. This keeps the permission
matrix a clean single-role-per-check rather than a matrix of role combinations.

---

## 7. Complete Alert Lifecycle Example

Concrete walkthrough, School ID 4, student Jane Doe (user id 88), responder Mr. Santos (user id
15, `responders.school_id = 4`):

1. **19:30:00** — Jane performs her configured Pulse gesture. On-device TFLite inference exceeds
   the confidence threshold. `EmergencyActivationScreen` triggers.
2. **19:30:01** — GPS captured: `11.2449, 125.0037`, accuracy 10.5m. If GPS fails/times out,
   coordinates are stored null and the flow continues (does not block the alert).
3. **19:30:01** — Local alert record created in on-device storage:
   `{status: ACTIVE, delivery_status: QUEUED, is_test: false}`.
4. **19:30:02** — Connectivity check: internet available → attempt `CLOUD`.
   `alert_delivery_attempts` (once synced) will show `method=CLOUD, status=SENDING`.
5. **19:30:04** — `POST /api/alerts` succeeds. Backend: inserts `emergency_alerts`
   (`status=RECEIVED, received_at=19:30:04, delivery_method=CLOUD, delivery_status=DELIVERED`),
   inserts `alert_delivery_attempts` (`DELIVERED`), writes `audit_logs` (`alert_received`,
   user_id=88), pushes notification to all responders where `school_id=4` (including Mr.
   Santos).
6. **19:30:04** — App enters Cloak Mode; local record's status synced to `RECEIVED`.
7. **19:30:20** — Mr. Santos's dashboard shows the new alert card (poll or push); he clicks
   `[VIEW]` → `GET /api/alerts/1042` → sees Jane's name, school, GPS, no responders assigned yet.
8. **19:30:35** — Mr. Santos clicks `[ACKNOWLEDGE]` → `POST /api/alerts/1042/acknowledge`.
   Backend checks status is `RECEIVED` ✅ → updates `status=ACKNOWLEDGED,
   acknowledged_at=19:30:35, acknowledged_by=15` → `audit_logs` (`alert_acknowledged`) → push to
   Jane's device: discreet "Response Team Notified" line added to her Cloak-mode status view.
9. **19:31:10** — Mr. Santos heads to Jane's location, clicks `[RESPOND]` →
   `POST /api/alerts/1042/respond`. Status check `ACKNOWLEDGED` ✅ → `status=RESPONDING,
   responded_at=19:31:10, responded_by=15` → audit log → Jane's app: "Responder En Route".
10. **19:35:40** — Mr. Santos locates Jane, confirms she's safe (accidental trigger). Clicks
    `[RESOLVE]`, enters resolution note "Accidental trigger, student confirmed safe." →
    `POST /api/alerts/1042/resolve`. Status check `RESPONDING` ✅ → `status=RESOLVED,
    resolved_at=19:35:40, resolved_by=15, resolution_note=...` → audit log → Jane's app:
    "Response Complete".
11. Incident now appears in **Incident History** for School 4 with the full timestamp trail
    (`received_at` → `resolved_at` = 5m36s total response time) and `resolved_by = Mr. Santos`.

---

## 8. Implementation-Status Labels

Every subsystem below will carry one of these five labels throughout the codebase (in code
comments and in `docs/`), so nothing is ever implied to work beyond what's actually true:

| Subsystem | Label | Why |
|---|---|---|
| Auth, roles, alert CRUD, state machine, permission checks | **IMPLEMENTED IN CODE** | Pure server/app logic, no external dependency. |
| REST API + DB migrations | **IMPLEMENTED IN CODE** | Runs against any MySQL instance once you provide one. |
| SMS delivery | **MOCK/DEVELOPMENT ONLY** until `SMS_API_KEY` etc. are supplied → then **REQUIRES EXTERNAL SERVICE** | `SmsService` interface implemented against a mock in dev; real provider (e.g. Twilio) needed for actual delivery. |
| GPS capture | **IMPLEMENTED IN CODE**, but **REQUIRES DEVICE TESTING** | `geolocator`/platform GPS APIs are real; permission-grant flows and accuracy behavior vary by device and must be verified on hardware, not just emulator. |
| Push notifications to dashboard/mobile | **REQUIRES EXTERNAL SERVICE** (Firebase or equivalent) | No push infra exists without a configured project; Phase 4 ships polling as the working fallback so the dashboard functions without it. |
| Maps (dashboard + mobile) | **REQUIRES EXTERNAL SERVICE** (`GOOGLE_MAPS_API_KEY`) | No map tiles render without a key; UI is built against the integration point. |
| Foreground (app-open) gesture detection | **IMPLEMENTED IN CODE** | Sensor stream + TFLite mock detector, runs reliably while app is foregrounded. |
| Backgrounded (minimized) gesture detection | **IMPLEMENTED IN CODE**, but **REQUIRES DEVICE TESTING** | Android foreground service is implemented; actual reliability under OEM battery management can only be confirmed on real devices, per §3. |
| Locked-screen gesture detection | **NOT IN PHASE 2 SCOPE** | Not implemented; would require dedicated per-OEM testing, flagged as a later decision. |
| TensorFlow Lite gesture model | **MOCK/DEVELOPMENT ONLY** until you supply a trained `.tflite` file → then **REQUIRES TRAINED AI MODEL** | Detector interface + placeholder detector built in Phase 6; no labeled gesture dataset exists to train a real model in this environment. |
| Offline queue/retry | **IMPLEMENTED IN CODE** | Local storage + retry-on-reconnect logic doesn't depend on external services. |

---

## 9. Feature Scope Discipline

No features beyond the original spec are added as *required*. One clarification is being
introduced because the state machine in §1 genuinely needs it, and it's called out explicitly as
optional-adjacent:

- **`resolution_note` required on resolve, `cancellation_reason` required on cancel** — not in
  v1's original field list, but necessary for the state machine you asked for in §1 (an incident
  record with no explanation of how a real emergency or a cancellation was closed out is a gap in
  an audit trail for a safety system). This is treated as part of the core state machine, not an
  optional add-on, since §1 was requested as a requirement.

Explicitly marked **OPTIONAL — not built unless you ask**:
- Enforcing `is_available` to block/allow acknowledgment (currently advisory only, §5.4).
- Responder-side audit log viewing (permission matrix currently gives this to admin only, per
  original spec §16/§17 which lists "system logs" under Admin, not Responder).
- WebSocket/live-push dashboard updates (Phase 4 default is polling, which fully satisfies the
  spec; WebSocket is a possible later upgrade, not required for MVP).

---

**Revised Phase 1 is now consistent on: state machine, delivery-method/status modeling,
background-detection claims, full API contract, responder provisioning, permission matrix, one
worked example, and implementation-status labeling. Holding for your approval before Phase 2.**
