# PHASE 5 — PRODUCTION INTEGRATION & DEPLOYMENT

## Purpose
Connect the existing Flutter mobile app, Laravel/PHP backend, MariaDB database, and responder/admin dashboard in a real environment and verify that they work together reliably.

**Do not start Phase 6 during this phase.**

## 1. Read Existing Documentation First
Inspect:
- `docs/ARCHITECTURE.md`
- `docs/PHASE3_STATUS.md`
- `docs/PHASE4_STATUS.md`
- Other existing documentation in `docs/`

Previous architecture and phase decisions remain the source of truth. Do not redesign working systems unnecessarily.

## 2. Phase 5 Objectives
Complete and verify:
- Production Laravel/PHP backend
- Production MariaDB database
- Flutter mobile app connected to the production API
- Responder/Admin dashboard connected to the production API
- Authentication/Sanctum
- CORS
- HTTPS
- Production environment variables and secrets
- Deployment
- End-to-end integration testing
- Security verification
- Real-device testing where available
- Deployment/setup documentation

## 3. Identify How Each Component Runs
Document the actual commands for each component.

### Flutter Mobile
Document commands to install dependencies, run the app, configure the API URL, and build/release it.

### Laravel Backend
Document commands to install Composer dependencies, configure `.env`, run migrations, start locally, and run tests.

### MariaDB
Document the required database, configuration, migrations, and seed data if applicable.

### Dashboard
Inspect its actual `package.json` and framework configuration. Document commands to install dependencies, run locally, build, and deploy.

**Do not assume `npm run dev` unless the dashboard actually defines that script.**

## 4. Production Backend
Configure and deploy the existing Laravel backend.

Verify:
- Production `.env`
- Database connection
- Sanctum/authentication
- CORS
- HTTPS
- Production settings
- Debug mode disabled
- Secure environment variables
- API routes

Never commit `.env`, passwords, database credentials, API keys, tokens, private keys, or other secrets.

## 5. Production MariaDB
Set up the production MariaDB database.

Verify:
- Database connection
- Required migrations
- Required tables
- Foreign keys
- Correct database permissions
- Production-safe configuration
- Existing Phase 3/4 data model remains intact

Do not unnecessarily change the database schema.

## 6. Production Dashboard
Deploy the existing responder/admin dashboard and configure it to use the production Laravel API.

Verify:
- Login/authentication
- Responder permissions
- Admin permissions
- School-based access control
- Alert listing/details
- Acknowledge
- Respond
- Resolve
- Cancel where permitted
- History/audit information
- API errors
- Refresh/polling behavior

## 7. Production Flutter App
Connect the existing Flutter application to the production API.

Verify:
- Authentication
- API connectivity
- Emergency alert creation
- Alert status retrieval
- Alert history where implemented
- Error handling
- Production API URL
- Real-device connectivity where available

## 8. End-to-End Integration Test
Perform:

**Student Mobile → Emergency Alert → Laravel API → MariaDB → Responder Dashboard → Acknowledge → Respond → Resolve → Student Status → Audit Log**

Verify the alert reaches the backend, is stored correctly, respects school scoping, follows the approved state machine, updates student status, and creates the required audit/delivery records.

## 9. Security Verification
Check:
- Authentication
- Role authorization
- Responder authorization
- School-based access control
- Admin permissions
- HTTPS
- CORS
- Production environment configuration
- Database credentials
- Debug mode
- Error responses
- Secret handling
- GitHub for accidentally committed secrets

Do not claim a security check is complete unless it was actually performed.

## 10. Required Testing

### Mobile → API
- Student login
- Student creates an alert
- Alert reaches backend
- Alert is stored in MariaDB
- Student retrieves alert status

### Dashboard → API
- Responder login
- Responder sees permitted alerts
- Responder cannot access another school's alerts
- Acknowledge
- Respond
- Resolve
- Invalid transitions
- Unauthorized actions

### Database
- Alert record
- Delivery attempt
- Audit log
- State changes
- Timestamps and actor information

### API Errors
Verify relevant:
- `401` unauthenticated
- `403` unauthorized
- `404` not found
- `409` invalid/conflicting state
- `422` validation errors

### Real Device
Where available, test the Flutter app on a real device against the production API.

## 11. Deployment Verification
After deployment, verify:
- Backend is reachable
- Database is reachable
- Dashboard is reachable
- Flutter app reaches the production API
- HTTPS works
- Authentication works
- API endpoints work
- Database writes work
- Alert lifecycle works
- Audit logging works
- Error handling works

Do not put passwords, tokens, private keys, or other secrets in documentation.

## 12. Documentation
Create/update:

`docs/PHASE5_STATUS.md`

Record:
- Phase 5 objective
- Components deployed
- Environment/setup requirements
- Actual run/build commands
- Production configuration
- Tests performed
- Test results
- Security checks
- Deployment status
- Known problems
- Remaining gaps
- Final Phase 5 status

Clearly distinguish **Planned**, **In Progress**, **Verified**, and **Blocked**. Do not invent results.

## 13. Phase 5 Acceptance Criteria
Use:

`PHASE 5 VERIFIED — READY FOR PHASE 6`

only when all required items have actually been completed and tested:
- Flutter connected to production API
- Laravel deployed
- MariaDB configured
- Dashboard deployed
- Authentication and authorization work
- School scoping works
- Emergency alert creation works
- Alert lifecycle works end-to-end
- Audit logging works
- Delivery tracking works
- API error handling works
- HTTPS/CORS reviewed
- Security checks completed
- Production integration tested
- Real-device testing performed where available
- No critical unresolved production blocker remains

Otherwise use:

`PHASE 5 NOT VERIFIED — PHASE 6 BLOCKED`

## 14. Restrictions
Do NOT:
- Start Phase 6
- Add unrelated features
- Add unnecessary AI or analytics
- Add new roles without approval
- Redesign the architecture without a documented reason
- Replace working systems unnecessarily
- Fake test results
- Claim deployment without actually deploying
- Claim security verification without performing it
- Commit secrets
- Invent production URLs
- Delete previous phase documentation

## Phase 5 Focus

**Integrate → Deploy → Test → Secure → Verify**

The objective is not to build a new system. The objective is to prove that the systems already built work together reliably in a real environment.
