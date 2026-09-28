<?php

namespace App\Http\Controllers;

use App\Http\Resources\EmergencyAlertResource;
use App\Models\EmergencyAlert;
use App\Services\AlertAuthorization;
use Illuminate\Http\Request;

// docs/ARCHITECTURE.md §4 GET /dashboard/statistics and GET /dashboard/active-alerts —
// responder (own school) or admin.
class DashboardController extends Controller
{
    public function __construct(private readonly AlertAuthorization $authz)
    {
    }

    public function statistics(Request $request)
    {
        $user = $request->user();

        if (!$user->isAdmin() && !$user->isResponder()) {
            abort(403, 'Only responders and admins may view dashboard statistics.');
        }

        $base = EmergencyAlert::query()->where('is_test', false);

        if (!$user->isAdmin()) {
            $base->where('school_id', $this->authz->responderSchoolId($user));
        } elseif ($request->filled('school_id')) {
            $base->where('school_id', (int) $request->query('school_id'));
        }

        return response()->json([
            'active' => (clone $base)->where('status', EmergencyAlert::STATUS_RECEIVED)->count(),
            'acknowledged' => (clone $base)->where('status', EmergencyAlert::STATUS_ACKNOWLEDGED)->count(),
            'responding' => (clone $base)->where('status', EmergencyAlert::STATUS_RESPONDING)->count(),
            'resolved_today' => (clone $base)
                ->where('status', EmergencyAlert::STATUS_RESOLVED)
                ->whereDate('resolved_at', now()->toDateString())
                ->count(),
        ]);
    }

    public function activeAlerts(Request $request)
    {
        $user = $request->user();

        if (!$user->isAdmin() && !$user->isResponder()) {
            abort(403, 'Only responders and admins may view active alerts.');
        }

        $query = EmergencyAlert::query()
            ->whereIn('status', [
                EmergencyAlert::STATUS_RECEIVED,
                EmergencyAlert::STATUS_ACKNOWLEDGED,
                EmergencyAlert::STATUS_RESPONDING,
            ])
            ->with(['acknowledgedBy', 'respondedBy']);

        if (!$user->isAdmin()) {
            $query->where('school_id', $this->authz->responderSchoolId($user));
        } elseif ($request->filled('school_id')) {
            $query->where('school_id', (int) $request->query('school_id'));
        }

        if (!$request->boolean('include_test', false)) {
            $query->where('is_test', false);
        }

        return EmergencyAlertResource::collection($query->orderByDesc('activated_at')->get());
    }
}
