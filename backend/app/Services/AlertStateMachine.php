<?php

namespace App\Services;

use App\Exceptions\InvalidAlertTransitionException;
use App\Models\EmergencyAlert;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * The single authority for every emergency_alerts.status change.
 *
 * Implements exactly docs/ARCHITECTURE.md §1 / the Phase 3 brief §1 and §5:
 *
 *   ACTIVE → RECEIVED → ACKNOWLEDGED → RESPONDING → RESOLVED
 *
 * CANCELLED only from ACTIVE/RECEIVED/ACKNOWLEDGED. No backward transitions.
 * RESPONDING can never be cancelled — only resolved. RESOLVED/CANCELLED are
 * terminal.
 *
 * No controller should ever call `$alert->update(['status' => ...])`
 * directly — every transition goes through here so the precondition check,
 * the timestamp/actor columns, and the audit log entry can never drift out
 * of sync with each other. This class does NOT do role/school authorization
 * (see AlertAuthorization) — it only enforces "is this transition legal
 * given the alert's current status", which is orthogonal to "is this user
 * allowed to attempt it at all".
 */
class AlertStateMachine
{
    public function __construct(private readonly AuditLogger $audit)
    {
    }

    /**
     * The backend never separately stores an ACTIVE row — the mobile app's
     * ACTIVE state is local-only (docs §1.4: "backend, automatically, on
     * successful ingest" is the ACTIVE→RECEIVED transition). POST
     * /api/alerts therefore creates the row directly at RECEIVED, per the
     * Phase 3 brief §2 ("initial server status is RECEIVED").
     */
    public function receive(array $attributes, User $user, Request $request): EmergencyAlert
    {
        return DB::transaction(function () use ($attributes, $user, $request) {
            $alert = EmergencyAlert::create(array_merge($attributes, [
                'user_id' => $user->id,
                'school_id' => $user->school_id,
                'status' => EmergencyAlert::STATUS_RECEIVED,
                'received_at' => now(),
                // Phase 3 brief §2: delivery_status is DELIVERED when the
                // successful delivery method reached the server — reaching
                // this line at all means it did.
                'delivery_status' => EmergencyAlert::DELIVERY_STATUS_DELIVERED,
            ]));

            $alert->deliveryAttempts()->create([
                'method' => $alert->delivery_method,
                'status' => EmergencyAlert::DELIVERY_STATUS_DELIVERED,
                'attempted_at' => now(),
            ]);

            $this->audit->log('alert_received', $user, $alert->id, $request);

            return $alert;
        });
    }

    public function acknowledge(EmergencyAlert $alert, User $responder, Request $request): EmergencyAlert
    {
        return $this->transition(
            alert: $alert,
            allowedCurrentStatuses: [EmergencyAlert::STATUS_RECEIVED],
            changes: [
                'status' => EmergencyAlert::STATUS_ACKNOWLEDGED,
                'acknowledged_at' => now(),
                'acknowledged_by' => $responder->id,
            ],
            auditAction: 'alert_acknowledged',
            actor: $responder,
            request: $request,
        );
    }

    public function respond(EmergencyAlert $alert, User $responder, Request $request): EmergencyAlert
    {
        return $this->transition(
            alert: $alert,
            allowedCurrentStatuses: [EmergencyAlert::STATUS_ACKNOWLEDGED],
            changes: [
                'status' => EmergencyAlert::STATUS_RESPONDING,
                'responded_at' => now(),
                'responded_by' => $responder->id,
            ],
            auditAction: 'alert_responding',
            actor: $responder,
            request: $request,
        );
    }

    public function resolve(EmergencyAlert $alert, User $responder, string $resolutionNote, Request $request): EmergencyAlert
    {
        return $this->transition(
            alert: $alert,
            allowedCurrentStatuses: [EmergencyAlert::STATUS_RESPONDING],
            changes: [
                'status' => EmergencyAlert::STATUS_RESOLVED,
                'resolved_at' => now(),
                'resolved_by' => $responder->id,
                'resolution_note' => $resolutionNote,
            ],
            auditAction: 'alert_resolved',
            actor: $responder,
            request: $request,
        );
    }

    /**
     * @param bool $actorIsOwner true if $actor is the student/staff user the
     *     alert belongs to (not a responder/admin acting on someone else's
     *     alert). Determines which current statuses are eligible — see
     *     docs/ARCHITECTURE.md §1.3 and the Phase 3 brief §5.
     */
    public function cancel(
        EmergencyAlert $alert,
        User $actor,
        string $reason,
        bool $actorIsOwner,
        Request $request,
    ): EmergencyAlert {
        $allowed = $actorIsOwner
            ? [EmergencyAlert::STATUS_ACTIVE, EmergencyAlert::STATUS_RECEIVED]
            : [EmergencyAlert::STATUS_ACTIVE, EmergencyAlert::STATUS_RECEIVED, EmergencyAlert::STATUS_ACKNOWLEDGED];

        return $this->transition(
            alert: $alert,
            allowedCurrentStatuses: $allowed,
            changes: [
                'status' => EmergencyAlert::STATUS_CANCELLED,
                'cancelled_at' => now(),
                'cancelled_by' => $actor->id,
                'cancellation_reason' => $reason,
            ],
            auditAction: $actorIsOwner ? 'alert_cancelled_by_user' : 'alert_cancelled_by_responder',
            actor: $actor,
            request: $request,
            guard: function (EmergencyAlert $locked) use ($actorIsOwner): void {
                // docs/ARCHITECTURE.md §4 (POST /alerts/{id}/cancel): once a
                // responder has acknowledged, cancellation is a
                // responder/admin power — the alerting user gets 403
                // ("role/state not permitted"), not 409.
                if ($actorIsOwner && $locked->status === EmergencyAlert::STATUS_ACKNOWLEDGED) {
                    throw new AuthorizationException(
                        'Only a responder or admin may cancel an alert after it has been acknowledged.',
                    );
                }
            },
        );
    }

    /**
     * Every non-create transition runs here: one transaction holding a
     * `SELECT ... FOR UPDATE` row lock across the precondition check, the
     * status/actor/timestamp write and the audit_logs insert (Phase 3 brief
     * §7). Two responders racing to acknowledge the same alert therefore
     * serialize — the loser re-reads ACKNOWLEDGED and gets 409 — and a
     * failed audit insert rolls the status change back rather than leaving
     * an unlogged history gap.
     *
     * @param  array<string, mixed>  $changes
     * @param  (\Closure(EmergencyAlert): void)|null  $guard  extra authorization check that can only be
     *     decided once the current status is known under lock.
     *
     * @throws InvalidAlertTransitionException
     */
    private function transition(
        EmergencyAlert $alert,
        array $allowedCurrentStatuses,
        array $changes,
        string $auditAction,
        User $actor,
        Request $request,
        ?\Closure $guard = null,
    ): EmergencyAlert {
        return DB::transaction(function () use (
            $alert,
            $allowedCurrentStatuses,
            $changes,
            $auditAction,
            $actor,
            $request,
            $guard
        ) {
            $locked = EmergencyAlert::query()
                ->whereKey($alert->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            if ($guard !== null) {
                $guard($locked);
            }

            $this->assertCurrentStatus($locked, $allowedCurrentStatuses);

            $locked->update($changes);

            $this->audit->log($auditAction, $actor, $locked->id, $request);

            return $locked;
        });
    }

    /**
     * @throws InvalidAlertTransitionException
     */
    private function assertCurrentStatus(EmergencyAlert $alert, array $allowedCurrentStatuses): void
    {
        if (!in_array($alert->status, $allowedCurrentStatuses, true)) {
            throw new InvalidAlertTransitionException(
                currentStatus: $alert->status,
                message: "Alert {$alert->id} is currently {$alert->status}; this action requires one of: "
                    . implode(', ', $allowedCurrentStatuses) . '.',
            );
        }
    }
}
