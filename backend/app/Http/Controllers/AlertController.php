<?php

namespace App\Http\Controllers;

use App\Exceptions\InvalidAlertTransitionException;
use App\Http\Requests\CancelAlertRequest;
use App\Http\Requests\ResolveAlertRequest;
use App\Http\Requests\StoreAlertRequest;
use App\Http\Resources\EmergencyAlertResource;
use App\Models\EmergencyAlert;
use App\Services\AlertAuthorization;
use App\Services\AlertStateMachine;
use App\Services\AuditLogger;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class AlertController extends Controller
{
    public function __construct(
        private readonly AlertStateMachine $stateMachine,
        private readonly AlertAuthorization $authz,
        private readonly AuditLogger $audit,
    ) {
    }

    /**
     * POST /api/alerts — student/staff only (route middleware: role:student,staff).
     * docs/ARCHITECTURE.md §4 + Phase 3 brief §2. The backend never stores a
     * row at ACTIVE — this creates directly at RECEIVED, since reaching
     * this endpoint at all means a delivery attempt already succeeded
     * (StoreAlertRequest rejects delivery_method values other than
     * CLOUD/SMS — PENDING/QUEUED can never be POSTed).
     */
    public function store(StoreAlertRequest $request)
    {
        $user = $request->user();

        $this->flagIfRepeatedNonTestAlerts($user, $request);

        $alert = $this->stateMachine->receive($request->validated(), $user, $request);

        return response()->json([
            'id' => $alert->id,
            'status' => $alert->status,
            'received_at' => $alert->received_at->toIso8601String(),
        ], 201);
    }

    /**
     * GET /api/alerts — responder (own school only) or admin (all schools,
     * ?school_id= optional filter). docs/ARCHITECTURE.md §4.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        if (!$user->isAdmin() && !$user->isResponder()) {
            abort(403, 'Only responders and admins may list alerts.');
        }

        $query = EmergencyAlert::query()->with(['acknowledgedBy', 'respondedBy', 'resolvedBy', 'cancelledBy']);

        if ($user->isAdmin()) {
            if ($request->filled('school_id')) {
                $query->where('school_id', (int) $request->query('school_id'));
            }
        } else {
            $responderSchoolId = $this->authz->responderSchoolId($user);

            if ($request->filled('school_id') && (int) $request->query('school_id') !== $responderSchoolId) {
                abort(403, 'You may only list alerts for your own school.');
            }

            $query->where('school_id', $responderSchoolId);
        }

        if ($request->filled('status')) {
            $query->where('status', strtoupper($request->query('status')));
        }

        // include_test defaults to false — test alerts excluded unless explicitly requested.
        if (!$request->boolean('include_test', false)) {
            $query->where('is_test', false);
        }

        if ($request->filled('from')) {
            $query->where('activated_at', '>=', Carbon::parse($request->query('from')));
        }
        if ($request->filled('to')) {
            $query->where('activated_at', '<=', Carbon::parse($request->query('to')));
        }

        $alerts = $query->orderByDesc('activated_at')->paginate(25);

        return EmergencyAlertResource::collection($alerts);
    }

    /**
     * GET /api/alerts/{alert} — responder/admin (own school) OR the
     * alerting user themself.
     */
    public function show(Request $request, EmergencyAlert $alert)
    {
        $user = $request->user();

        $isOwner = $alert->user_id === $user->id;

        if (!$isOwner) {
            $this->authz->assertCanActOnAlertAsResponder($user, $alert);
        }

        $alert->load(['acknowledgedBy', 'respondedBy', 'resolvedBy', 'cancelledBy']);

        return new EmergencyAlertResource($alert);
    }

    // POST /api/alerts/{alert}/acknowledge — responder (own school) or admin.
    public function acknowledge(Request $request, EmergencyAlert $alert)
    {
        $user = $request->user();
        $this->authz->assertCanActOnAlertAsResponder($user, $alert);

        $alert = $this->handleTransition(fn () => $this->stateMachine->acknowledge($alert, $user, $request));

        return new EmergencyAlertResource($alert);
    }

    // POST /api/alerts/{alert}/respond
    public function respond(Request $request, EmergencyAlert $alert)
    {
        $user = $request->user();
        $this->authz->assertCanActOnAlertAsResponder($user, $alert);

        $alert = $this->handleTransition(fn () => $this->stateMachine->respond($alert, $user, $request));

        return new EmergencyAlertResource($alert);
    }

    // POST /api/alerts/{alert}/resolve
    public function resolve(ResolveAlertRequest $request, EmergencyAlert $alert)
    {
        $user = $request->user();
        $this->authz->assertCanActOnAlertAsResponder($user, $alert);

        $alert = $this->handleTransition(
            fn () => $this->stateMachine->resolve($alert, $user, $request->string('resolution_note'), $request),
        );

        return new EmergencyAlertResource($alert);
    }

    // POST /api/alerts/{alert}/cancel — owner (pre-acknowledge) OR responder/admin (own school).
    public function cancel(CancelAlertRequest $request, EmergencyAlert $alert)
    {
        $user = $request->user();
        $isOwner = $alert->user_id === $user->id;

        if (!$isOwner) {
            $this->authz->assertCanActOnAlertAsResponder($user, $alert);
        }

        $alert = $this->handleTransition(
            fn () => $this->stateMachine->cancel($alert, $user, $request->string('cancellation_reason'), $isOwner, $request),
        );

        return new EmergencyAlertResource($alert);
    }

    /**
     * Runs a state-machine transition and converts
     * InvalidAlertTransitionException into the approved 409 shape (current
     * status included so the client can resync) — docs/ARCHITECTURE.md
     * §1.4 / Phase 3 brief §5.
     */
    private function handleTransition(\Closure $transition): EmergencyAlert
    {
        try {
            // Actor relations are eager-loaded so a transition response
            // carries the same expanded acknowledged_by/responded_by/
            // resolved_by/cancelled_by shape as GET /alerts/{id} (§4).
            return $transition()->load(['acknowledgedBy', 'respondedBy', 'resolvedBy', 'cancelledBy']);
        } catch (InvalidAlertTransitionException $e) {
            abort(response()->json([
                'message' => $e->getMessage(),
                'current_status' => $e->currentStatus,
            ], 409));
        }
    }

    /**
     * Phase 3 brief §2 / docs/ARCHITECTURE.md §4: "this endpoint is exempt
     * from normal API rate limits ... but is monitored — repeated non-test
     * alerts from the same user in a short window are flagged in
     * audit_logs for admin review rather than blocked." Lightweight
     * threshold check, not a blocking mechanism.
     */
    private function flagIfRepeatedNonTestAlerts($user, Request $request): void
    {
        if ($request->boolean('is_test', false)) {
            return;
        }

        $recentCount = EmergencyAlert::where('user_id', $user->id)
            ->where('is_test', false)
            ->where('created_at', '>=', now()->subMinutes(10))
            ->count();

        if ($recentCount >= 3) {
            $this->audit->log('repeated_alert_flagged', $user, null, $request);
        }
    }
}
