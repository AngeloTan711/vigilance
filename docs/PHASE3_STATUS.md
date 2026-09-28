# VIGILANCE — Phase 3 Status: Laravel Backend

Phase 3 (Backend) implements the alert lifecycle API, state machine, responder
authorization/school-scoping, audit logging, and delivery tracking against the approved Phase 1
architecture (`docs/ARCHITECTURE.md`).

**This revision of the document replaces the earlier "not executed anywhere" status.** The
backend has now actually been run: dependencies installed, migrations applied to a real
MariaDB server, and the full PHPUnit suite executed against both SQLite and MariaDB. §6 lists
exactly what was run and what was *not*. Claims below are labelled by how they were established
(`VERIFIED BY TEST` vs `IMPLEMENTED IN CODE`), per §8.

---

## 1. What Was Implemented

- **Migrations** (`database/migrations/`): `schools`, `users` (with soft deletes), `responders`,
  `emergency_contacts`, `emergency_alerts` (full state-machine + delivery columns from
  `docs/ARCHITECTURE.md` §1.5/§2.3 folded into one CREATE), `alert_delivery_attempts`,
  `audit_logs`, `personal_access_tokens` (Sanctum).
- **Models**: `School`, `User` (with `isResponder()`/`isAdmin()`), `Responder`,
  `EmergencyContact`, `EmergencyAlert` (status/delivery constants + all relations),
  `AlertDeliveryAttempt`, `AuditLog`.
- **`AlertStateMachine`** — the single place `emergency_alerts.status` is ever written.
  Implements exactly `ACTIVE → RECEIVED → ACKNOWLEDGED → RESPONDING → RESOLVED`, `CANCELLED`
  only from `ACTIVE`/`RECEIVED`/`ACKNOWLEDGED`, no backward transitions, `RESPONDING` never
  cancellable. Every transition now runs inside one `DB::transaction()` holding a
  `lockForUpdate()` row lock across *re-read → precondition check → status write → audit
  insert* (see §2.1).
- **`AlertAuthorization`** — responder-school-scope + role checks, re-derived from the DB every
  time, never from client-supplied role/school_id; writes a `responder_record_missing` audit
  entry when `role=responder` has no `responders` row (§5 point 3 of the architecture).
- **`ResponderProvisioningService`** — the only path that creates `users.role='responder'`,
  always paired atomically (one DB transaction) with a `responders` row.
- **`AuditLogger`** — one call site for every `audit_logs` insert.
- **Controllers**: Auth, Profile, EmergencyContact, Alert
  (store/index/show/acknowledge/respond/resolve/cancel), Responder, School, Student, Dashboard,
  Admin\ResponderProvisioning.
- **Form Requests** for every mutating endpoint, matching the approved validation rules exactly.
- **Routes** (`routes/api.php`) — every endpoint from `docs/ARCHITECTURE.md` §4.
- **Laravel runtime skeleton** — `artisan`, `config/`, `public/`, `storage/`, `bootstrap/cache/`
  (see §2.1, defect D1: the previous delivery shipped application code only and could not boot).
- **Feature tests** (`tests/Feature/`) — 29 test methods covering the 25 required scenarios.
- **`DatabaseSeeder`** — School id=1, one student, one responder, one admin.

## 2. Audit Findings and Fixes (this pass)

### 2.1 Defects found and fixed

| # | Defect | Evidence | Fix |
|---|---|---|---|
| D1 | The ZIP contained no `artisan`, `config/`, `public/`, `storage/` or `bootstrap/cache` — `composer install` aborted on `@php artisan package:discover` and **no artisan command could run at all**, so nothing in the previous status document could ever have been executed. | `Could not open input file: artisan` | Added the standard Laravel 11 runtime skeleton (`laravel/laravel` v11 `artisan`, `config/*`, `public/*`, `storage/*`, `bootstrap/cache/`). No application code was changed by this. |
| D2 | Single-record responses were wrapped in a `data` envelope, contradicting `docs/ARCHITECTURE.md` §4 (`200 OK, updated alert object`) and breaking the Phase 2 Flutter client, which reads `json['status']`/`json['id']` directly (`mobile/lib/models/emergency_alert.dart::fromServerJson`). 6 of the existing tests failed on this. | `assertJson(['status' => 'CANCELLED'])` failing against `{"data": {...}}` | `JsonResource::withoutWrapping()` in `AppServiceProvider::boot()`. Paginated list responses keep their `data`/`meta`/`links` structure, which §4 ("paginated array") and `SchoolScopeTest` both expect. |
| D3 | The alerting user cancelling an **acknowledged** alert got `409 Conflict`. §4 (`POST /alerts/{id}/cancel`) explicitly specifies `403` for that exact case ("role/state not permitted — e.g. student trying to cancel after `ACKNOWLEDGED`"); `409` is reserved for `RESPONDING`/`RESOLVED`/already-`CANCELLED`. | `test_student_cannot_cancel_after_acknowledgement` failed (409 ≠ 403) | Owner-specific guard evaluated **inside the locked transaction** (so the status it judges cannot be stale) throwing `AuthorizationException` → 403. Non-owner-permitted states still return 409. |
| D4 | **No concurrency control on any transition.** `acknowledge`/`respond`/`resolve`/`cancel` checked the status of an already-loaded (potentially stale) model, then updated, then wrote the audit row — three separate statements, no transaction, no row lock. Two responders acknowledging simultaneously could both succeed (double write, two audit rows, second overwriting `acknowledged_by`); an audit-insert failure left a committed status change with no history. | Code read of `AlertStateMachine` (pre-fix) | New private `AlertStateMachine::transition()`: one `DB::transaction()` that re-reads the row with `lockForUpdate()`, re-checks the precondition against the locked row, updates, and inserts the audit row. Loser of a race re-reads the new status and gets the normal 409. |
| D5 | `responder_record_missing` audit entry required by §5 point 3 was never written: `User::isResponder()` already returns false when the `responders` row is missing, so `AlertAuthorization` fell into the generic "not a responder" branch and the integrity case was indistinguishable in the logs. | Code read + `audit_logs` contents | `AlertAuthorization` now checks `role` first, then the `responders` row, and logs `responder_record_missing` before throwing the 403. |
| D6 | Transition responses (`acknowledge`/`respond`/`resolve`/`cancel`) omitted `acknowledged_by`/`responded_by`/`resolved_by`/`cancelled_by` entirely, because `EmergencyAlertResource` exposes them via `whenLoaded()` and the controller never loaded those relations — `GET /alerts/{id}` returned them, the transition endpoints did not. | Response bodies in test output | `AlertController::handleTransition()` eager-loads the four actor relations, so all single-alert responses share one shape. |

### 2.2 Checked and found correct (no change needed)

- State transition table, including the owner-vs-responder cancel distinction, matches §1 exactly.
- `delivery_method` (`PENDING`/`CLOUD`/`SMS`) and `delivery_status` (`QUEUED`/`SENDING`/
  `DELIVERED`/`FAILED`) remain two separate enums in the migration and the model;
  `StoreAlertRequest` rejects anything but `CLOUD`/`SMS`.
- `POST /alerts` produces `status=RECEIVED`, `delivery_status=DELIVERED`, one
  `alert_delivery_attempts` row and one `alert_received` audit row.
- Authorization never reads client-supplied `role`/`school_id`/`user_id`/`status`
  (now covered by an explicit test — scenario 22).
- Error contract: `401` unauthenticated, `403` role/school, `404` route-model binding,
  `409` + `current_status` on invalid transition, `422` `{message, errors}` on validation.
- `GET /alerts` school scoping, `?school_id=` rejection for responders, `include_test` default
  false; dashboard endpoints apply the same scoping.
- Responder provisioning (`users` + `responders` in one transaction) is the only creation path.

### 2.3 Not changed (deliberately)

- **Pint**: `./vendor/bin/pint --test` reports style deviations in 17 pre-existing files (the
  code uses `!$x` spacing, brace and import conventions that differ from the Laravel preset).
  Running `pint` would reformat almost the whole codebase, which is out of scope for a defect
  fix pass; only the newly added test file was formatted with Pint. This is a style-only
  finding — `php -l` is clean on every PHP file.

## 3. Verification Actually Performed

Environment built for this pass: **PHP 8.3.35**, **Composer 2.10.3**, **MariaDB 10.6.23**
(`mysql` connection, not SQLite).

| Command | Result |
|---|---|
| `composer install` | OK (after adding the runtime skeleton; previously failed on missing `artisan`) |
| `php artisan key:generate` | OK |
| `php artisan route:list` | 28 routes registered, matching `routes/api.php` |
| `php artisan migrate:fresh --seed` **against MariaDB 10.6** | All 8 migrations applied, seeders ran. MySQL/MariaDB schema compatibility is therefore **verified**, not assumed. |
| `php artisan test` (SQLite `:memory:`, per `phpunit.xml`) | **29 passed, 97 assertions** |
| `DB_CONNECTION=mysql … php artisan test` (MariaDB) | **29 passed, 97 assertions** (env override confirmed effective by a deliberate wrong-database run, which failed as expected) |
| `php -l` on every file in `app/ database/ routes/ tests/ config/` | No syntax errors |
| `./vendor/bin/pint --test` | Fails on 17 pre-existing files (style only) — see §2.3 |
| Real multi-process race on MariaDB (5 concurrent `acknowledge` on one alert) | 1 × success, 4 × `409 (ACKNOWLEDGED)`, final status `ACKNOWLEDGED`, exactly **1** `alert_acknowledged` audit row |

The concurrency result above was produced by five separate OS processes hitting the same row
through the real state machine on MariaDB (SQLite `:memory:` cannot be shared across processes,
so the in-suite concurrency test instead proves the stale-instance case: a transition attempted
with a model loaded *before* another actor won the race is rejected).

## 4. Test Scenario Coverage (25 required)

| # | Scenario | Test method | Status |
|---|---|---|---|
| 1 | Student creates alert | `test_student_can_create_an_alert` | VERIFIED BY TEST |
| 2 | Unauthenticated cannot create | `test_unauthenticated_user_cannot_create_an_alert` | VERIFIED BY TEST |
| 3 | Responder sees own-school alerts | `test_responder_can_view_alerts_from_own_school` | VERIFIED BY TEST |
| 4 | Responder cannot see other school | `test_responder_cannot_view_another_schools_alerts` | VERIFIED BY TEST |
| 5 | Acknowledge `RECEIVED` | `test_responder_can_acknowledge_received_alert` | VERIFIED BY TEST |
| 6 | Cannot acknowledge `ACKNOWLEDGED` | `test_cannot_acknowledge_an_already_acknowledged_alert` | VERIFIED BY TEST |
| 7 | `ACKNOWLEDGED → RESPONDING` | `test_responder_can_move_acknowledged_to_responding` | VERIFIED BY TEST |
| 8 | `RESPONDING → RESOLVED` | `test_responder_can_move_responding_to_resolved` | VERIFIED BY TEST |
| 9 | Resolution note required | `test_resolve_requires_resolution_note` | VERIFIED BY TEST |
| 10 | Cannot respond before ack | `test_cannot_respond_before_acknowledged` | VERIFIED BY TEST |
| 11 | Cannot resolve before responding | `test_cannot_resolve_before_responding` | VERIFIED BY TEST |
| 12 | Cannot cancel `RESPONDING` | `test_cannot_cancel_a_responding_alert` | VERIFIED BY TEST |
| 13 | Owner cancels own `RECEIVED` alert | `test_student_can_cancel_their_own_received_alert` | VERIFIED BY TEST (the `ACTIVE` case is unreachable server-side by design — §1.4) |
| 14 | Owner cannot cancel after ack (403) | `test_student_cannot_cancel_after_acknowledgement` | VERIFIED BY TEST (was failing before D3) |
| 15 | Cancellation reason required | `test_cancellation_requires_cancellation_reason` | VERIFIED BY TEST |
| 16 | Every transition audit-logged | `test_every_transition_creates_an_audit_log` | VERIFIED BY TEST |
| 17 | Delivery attempt recorded | asserted in `test_student_can_create_an_alert` | VERIFIED BY TEST |
| 18 | Admin school-scope permissions | `test_admin_can_view_and_act_across_schools` | VERIFIED BY TEST |
| 19 | Invalid transition → 409 | `test_cannot_acknowledge_an_already_acknowledged_alert`, `test_cannot_respond_before_acknowledged`, `test_cannot_resolve_before_responding`, `test_resolved_alert_cannot_transition_further` | VERIFIED BY TEST |
| 20 | Cross-school access denied | `test_responder_cannot_view_another_schools_alerts` (list, show, acknowledge) | VERIFIED BY TEST |
| 21 | Responder without responder record denied | `test_role_responder_without_responder_record_is_rejected` | VERIFIED BY TEST |
| 22 | Client-supplied role/school/status ignored | `test_client_supplied_role_school_and_status_are_ignored`, `test_student_cannot_acknowledge_by_claiming_responder_role` | VERIFIED BY TEST |
| 23 | Concurrent transitions handled safely | `test_concurrent_transitions_do_not_both_succeed` + the 5-process MariaDB race in §3 | VERIFIED BY TEST |
| 24 | State change + audit log atomic | `test_state_change_is_rolled_back_when_audit_logging_fails` | VERIFIED BY TEST |
| 25 | Invalid fields → 422 | `test_invalid_alert_fields_return_422`, `test_resolve_requires_resolution_note`, `test_cancellation_requires_cancellation_reason` | VERIFIED BY TEST |

## 5. Dependencies / Environment / Database

- **Composer**: `laravel/framework ^11.0`, `laravel/sanctum ^4.0` (+ dev: `phpunit/phpunit`,
  `laravel/pint`, `fakerphp/faker`). Installed and used for this verification.
  Note: `laravel/framework ^11.0` currently resolves to a version carrying published security
  advisories; Composer's advisory check had to be disabled to install it. **Upgrading the
  framework patch version is recommended** and is not a Phase 3 architecture change.
- **Environment variables**: as specified in `docs/ARCHITECTURE.md` §8. SMS/Maps/Firebase
  variables present but empty — nothing in this codebase assumes they have values.
- **Database**: MySQL/MariaDB verified (MariaDB 10.6.23). The suite also runs on SQLite
  in-memory per `phpunit.xml` for a dependency-free run.

## 6. What Was NOT Executed / Verified

- **Push notifications** to responders on new alerts — no Firebase credentials; no code path
  exists in Phase 3 (`REQUIRES EXTERNAL SERVICE`).
- **SMS sending** — out of Phase 3 scope by design (the device sends; the server records).
- **Google Maps** — nothing server-side.
- **End-to-end against the real Flutter client on a device** — not run here
  (`REQUIRES DEVICE/ENVIRONMENT TESTING`). The response-shape defect D2 was found by reading
  that client's parsing code, not by running it.
- **Load/soak testing, TLS, deployment hardening** — not in Phase 3 scope.
- **MySQL 8.x specifically** — verification used MariaDB 10.6; the schema uses no
  MariaDB-specific features, but MySQL 8 itself was not exercised.

## 7. How to Run

```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate
# point .env at MySQL/MariaDB, then:
php artisan migrate:fresh --seed
php artisan test                       # SQLite :memory:
DB_CONNECTION=mysql php artisan test   # against the real DB
php artisan serve                      # Flutter app talks to http://10.0.2.2:8000/api
```

## 8. Implementation-Status Table

| Component | Status |
|---|---|
| Alert state machine + transition legality | VERIFIED BY TEST |
| Transition atomicity (status + audit in one locked transaction) | VERIFIED BY TEST (incl. real 5-process race on MariaDB) |
| Responder authorization / school scoping / admin override | VERIFIED BY TEST |
| Authentication (Sanctum), role middleware | VERIFIED BY TEST |
| Audit logging on every alert transition + auth events | VERIFIED BY TEST |
| `alert_delivery_attempts` + delivery method/status separation | VERIFIED BY TEST |
| API error contract (401/403/404/409/422) | VERIFIED BY TEST |
| Migrations on MySQL/MariaDB | VERIFIED BY TEST (`migrate:fresh --seed` on MariaDB 10.6) |
| `responder_record_missing` integrity audit entry | IMPLEMENTED IN CODE (unreachable in normal data; not force-triggered in a test) |
| Dashboard/roster/schools endpoints | IMPLEMENTED IN CODE (scoping code-reviewed; only the alert-scoping paths are test-covered) |
| Rate-limit flagging of repeated alerts (`repeated_alert_flagged`) | IMPLEMENTED IN CODE (not test-covered) |
| Push notifications (Firebase) | REQUIRES EXTERNAL SERVICE |
| SMS sending | NOT IN PHASE 3 SCOPE (device-side, Phase 2) |
| Google Maps | REQUIRES EXTERNAL SERVICE |
| Real device / Flutter end-to-end run | REQUIRES DEVICE/ENVIRONMENT TESTING |
| Pint code-style conformance | MOCK/DEVELOPMENT ONLY — style deviations remain (§2.3) |

## 9. Known Gaps Carried Forward

- **No public schools-lookup endpoint** for self-registration. `GET /schools` remains
  admin-only per the approved spec; `DatabaseSeeder` seeds `school_id=1` as a stopgap.
- **No "list my own alerts" endpoint** — `GET /alerts` remains responder/admin-only per §4.
- **`POST /admin/responders`** is an extrapolation of §5 (which states the provisioning rule but
  gives no §4-style contract). Flagged, not silently settled.
- **`laravel/framework` advisory** noted in §5.

## 10. Gate Decision

All 25 required scenarios are covered by executed tests; all six defects found in this audit are
fixed; the suite is green on both SQLite and MariaDB; migrations apply cleanly to MariaDB.

**PHASE 3 VERIFIED — READY FOR PHASE 4.**
