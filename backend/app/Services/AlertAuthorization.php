<?php

namespace App\Services;

use App\Models\EmergencyAlert;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

/**
 * Phase 3 brief §4/§9 + docs/ARCHITECTURE.md §5: the single place that
 * decides whether an authenticated user may act on a given alert as a
 * responder. Never trusts role/school_id supplied by the frontend — both
 * are re-derived from the authenticated user's own database record
 * (`$user->responder`, loaded fresh from the DB via the relationship, not
 * anything the client sent).
 */
class AlertAuthorization
{
    public function __construct(private readonly AuditLogger $audit)
    {
    }

    /**
     * @throws AuthorizationException (→ 403, mapped in the exception handler)
     */
    public function assertCanActOnAlertAsResponder(User $user, EmergencyAlert $alert): void
    {
        if ($user->isAdmin()) {
            return; // Admins act across all schools per the approved permission matrix.
        }

        if ($user->role !== User::ROLE_RESPONDER) {
            throw new AuthorizationException('Only a responder or admin may perform this action.');
        }

        $responder = $user->responder; // Eloquent relationship — DB-backed, not client-supplied.

        if ($responder === null) {
            // role=responder with no responders row should never happen if
            // ResponderProvisioningService is the only creation path — but
            // if it does, treat it as a data-integrity problem, not a
            // silent pass-through (docs/ARCHITECTURE.md §5, point 3): 403
            // plus a `responder_record_missing` audit entry to investigate.
            $this->audit->log('responder_record_missing', $user, $alert->id, request());

            throw new AuthorizationException('Responder record missing for this account.');
        }

        if ($responder->school_id !== $alert->school_id) {
            throw new AuthorizationException('This alert does not belong to your school.');
        }
    }

    /** Used by GET /alerts and GET /dashboard/* to scope queries, not just single-record checks. */
    public function responderSchoolId(User $user): ?int
    {
        return $user->responder?->school_id;
    }
}
