<?php

namespace Tests\Feature;

use App\Exceptions\InvalidAlertTransitionException;
use App\Models\AuditLog;
use App\Models\EmergencyAlert;
use App\Models\School;
use App\Models\User;
use App\Services\AlertStateMachine;
use App\Services\AuditLogger;
use App\Services\ResponderProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use RuntimeException;
use Tests\TestCase;

/**
 * Phase 3 brief §10 scenarios 22 (client-supplied role/school manipulation),
 * 23 (concurrent transitions), 24 (state change + audit log atomicity) and
 * 25 (invalid request fields → 422).
 */
class AlertIntegrityTest extends TestCase
{
    use RefreshDatabase;

    private School $school;

    private School $otherSchool;

    private User $student;

    private User $responder;

    protected function setUp(): void
    {
        parent::setUp();

        $this->school = School::factory()->create();
        $this->otherSchool = School::factory()->create();
        $this->student = User::factory()->for($this->school)->create();

        $this->responder = app(ResponderProvisioningService::class)->provision(
            userAttributes: [
                'name' => 'Responder One',
                'email' => 'responder1@example.test',
                'phone' => '+10000000000',
                'password' => 'password123',
            ],
            schoolId: $this->school->id,
        );
    }

    private function receivedAlert(): EmergencyAlert
    {
        $response = $this->actingAs($this->student, 'sanctum')->postJson('/api/alerts', [
            'latitude' => 11.2449,
            'longitude' => 125.0037,
            'accuracy' => 10.5,
            'activated_at' => now()->subSeconds(2)->toIso8601String(),
            'delivery_method' => 'CLOUD',
            'is_test' => false,
        ]);

        return EmergencyAlert::findOrFail($response->json('id'));
    }

    /** Scenario 22: role/school_id/user_id/status sent by the client never decide anything. */
    public function test_client_supplied_role_school_and_status_are_ignored(): void
    {
        $response = $this->actingAs($this->student, 'sanctum')->postJson('/api/alerts', [
            'latitude' => 11.2449,
            'longitude' => 125.0037,
            'activated_at' => now()->subSeconds(2)->toIso8601String(),
            'delivery_method' => 'CLOUD',
            // Everything below is attacker-controlled noise.
            'role' => 'admin',
            'school_id' => $this->otherSchool->id,
            'user_id' => $this->responder->id,
            'status' => 'RESOLVED',
            'delivery_status' => 'FAILED',
            'resolved_by' => $this->responder->id,
        ]);

        $response->assertStatus(201)->assertJson(['status' => 'RECEIVED']);

        $alert = EmergencyAlert::findOrFail($response->json('id'));
        $this->assertSame($this->student->id, $alert->user_id);
        $this->assertSame($this->school->id, $alert->school_id);
        $this->assertSame(EmergencyAlert::STATUS_RECEIVED, $alert->status);
        $this->assertSame(EmergencyAlert::DELIVERY_STATUS_DELIVERED, $alert->delivery_status);
        $this->assertNull($alert->resolved_by);
    }

    /** Scenario 22 (second half): a student cannot acquire responder powers by claiming a role. */
    public function test_student_cannot_acknowledge_by_claiming_responder_role(): void
    {
        $alert = $this->receivedAlert();

        $this->actingAs($this->student, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/acknowledge", [
                'role' => 'responder',
                'school_id' => $this->school->id,
            ])
            ->assertStatus(403);

        $this->assertSame(EmergencyAlert::STATUS_RECEIVED, $alert->refresh()->status);
    }

    /**
     * Scenario 23: two actors racing the same transition. Each holds its own
     * (now stale) model instance, exactly as two concurrent HTTP requests
     * would after route-model binding. The state machine re-reads the row
     * under `lockForUpdate()` inside the transaction, so the loser sees
     * ACKNOWLEDGED and is rejected instead of double-writing.
     */
    public function test_concurrent_transitions_do_not_both_succeed(): void
    {
        $alert = $this->receivedAlert();

        $firstView = EmergencyAlert::findOrFail($alert->id);
        $secondView = EmergencyAlert::findOrFail($alert->id);

        $machine = app(AlertStateMachine::class);
        $request = Request::create("/api/alerts/{$alert->id}/acknowledge", 'POST');

        $machine->acknowledge($firstView, $this->responder, $request);

        $this->expectException(InvalidAlertTransitionException::class);

        try {
            $machine->acknowledge($secondView, $this->responder, $request);
        } finally {
            $this->assertSame(EmergencyAlert::STATUS_ACKNOWLEDGED, $alert->refresh()->status);
            $this->assertSame(
                1,
                AuditLog::where('alert_id', $alert->id)->where('action', 'alert_acknowledged')->count(),
            );
        }
    }

    /** Scenario 24: if the audit insert fails, the status change is rolled back with it. */
    public function test_state_change_is_rolled_back_when_audit_logging_fails(): void
    {
        $alert = $this->receivedAlert();

        $this->app->instance(AuditLogger::class, new class extends AuditLogger
        {
            public function log(string $action, ?User $user, ?int $alertId, ?Request $request = null): void
            {
                throw new RuntimeException('audit_logs write failed');
            }
        });

        try {
            app(AlertStateMachine::class)->acknowledge(
                $alert,
                $this->responder,
                Request::create("/api/alerts/{$alert->id}/acknowledge", 'POST'),
            );
            $this->fail('Expected the audit failure to propagate.');
        } catch (RuntimeException $e) {
            $this->assertSame('audit_logs write failed', $e->getMessage());
        }

        $alert->refresh();
        $this->assertSame(EmergencyAlert::STATUS_RECEIVED, $alert->status);
        $this->assertNull($alert->acknowledged_at);
        $this->assertNull($alert->acknowledged_by);
        $this->assertDatabaseMissing('audit_logs', [
            'alert_id' => $alert->id,
            'action' => 'alert_acknowledged',
        ]);
    }

    /** Scenario 25: invalid request fields return 422 in the approved error shape. */
    public function test_invalid_alert_fields_return_422(): void
    {
        $response = $this->actingAs($this->student, 'sanctum')->postJson('/api/alerts', [
            'latitude' => 999,
            'longitude' => 'not-a-number',
            'activated_at' => now()->addHour()->toIso8601String(),
            'delivery_method' => 'PENDING',
        ]);

        $response->assertStatus(422)
            ->assertJsonStructure(['message', 'errors'])
            ->assertJsonValidationErrors(['latitude', 'longitude', 'activated_at', 'delivery_method']);
    }
}
