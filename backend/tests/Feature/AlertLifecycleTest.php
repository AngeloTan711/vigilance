<?php

namespace Tests\Feature;

use App\Models\EmergencyAlert;
use App\Models\School;
use App\Models\User;
use App\Services\ResponderProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Covers Phase 3 brief §10 scenarios: 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13,
 * 14, 15, 16, 17. School-scope scenarios (3, 4, 18) are in
 * SchoolScopeTest.php.
 */
class AlertLifecycleTest extends TestCase
{
    use RefreshDatabase;

    private School $school;
    private User $student;
    private User $responder;
    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->school = School::factory()->create();
        $this->student = User::factory()->for($this->school)->create();
        $this->admin = User::factory()->for($this->school)->admin()->create();

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

    private function alertPayload(array $overrides = []): array
    {
        return array_merge([
            'latitude' => 11.2449,
            'longitude' => 125.0037,
            'accuracy' => 10.5,
            'activated_at' => now()->subSeconds(2)->toIso8601String(),
            'delivery_method' => 'CLOUD',
            'message' => 'Emergency assistance requested.',
            'is_test' => false,
        ], $overrides);
    }

    /** Scenario 1: Student can create an alert. */
    public function test_student_can_create_an_alert(): void
    {
        $response = $this->actingAs($this->student, 'sanctum')
            ->postJson('/api/alerts', $this->alertPayload());

        $response->assertStatus(201)
            ->assertJson(['status' => EmergencyAlert::STATUS_RECEIVED]);

        $this->assertDatabaseHas('emergency_alerts', [
            'user_id' => $this->student->id,
            'school_id' => $this->school->id,
            'status' => EmergencyAlert::STATUS_RECEIVED,
            'delivery_method' => 'CLOUD',
            'delivery_status' => EmergencyAlert::DELIVERY_STATUS_DELIVERED,
        ]);

        // Delivery attempt recorded (scenario 17).
        $alert = EmergencyAlert::first();
        $this->assertDatabaseHas('alert_delivery_attempts', [
            'emergency_alert_id' => $alert->id,
            'method' => 'CLOUD',
            'status' => 'DELIVERED',
        ]);

        // Audit log created (scenario 16).
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'alert_received',
            'alert_id' => $alert->id,
            'user_id' => $this->student->id,
        ]);
    }

    /** Scenario 2: Unauthenticated user cannot create an alert. */
    public function test_unauthenticated_user_cannot_create_an_alert(): void
    {
        $response = $this->postJson('/api/alerts', $this->alertPayload());

        $response->assertStatus(401);
        $this->assertDatabaseCount('emergency_alerts', 0);
    }

    private function receivedAlert(): EmergencyAlert
    {
        $response = $this->actingAs($this->student, 'sanctum')
            ->postJson('/api/alerts', $this->alertPayload());

        return EmergencyAlert::findOrFail($response->json('id'));
    }

    /** Scenario 5: Responder can acknowledge a RECEIVED alert. */
    public function test_responder_can_acknowledge_received_alert(): void
    {
        $alert = $this->receivedAlert();

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response->assertStatus(200)->assertJson(['status' => 'ACKNOWLEDGED']);

        $alert->refresh();
        $this->assertSame(EmergencyAlert::STATUS_ACKNOWLEDGED, $alert->status);
        $this->assertSame($this->responder->id, $alert->acknowledged_by);
        $this->assertNotNull($alert->acknowledged_at);

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'alert_acknowledged',
            'alert_id' => $alert->id,
            'user_id' => $this->responder->id,
        ]);
    }

    /** Scenario 6: Cannot acknowledge an already-ACKNOWLEDGED alert. */
    public function test_cannot_acknowledge_an_already_acknowledged_alert(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response->assertStatus(409)->assertJsonPath('current_status', 'ACKNOWLEDGED');
    }

    /** Scenario 7: Responder can move ACKNOWLEDGED → RESPONDING. */
    public function test_responder_can_move_acknowledged_to_responding(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/respond");

        $response->assertStatus(200)->assertJson(['status' => 'RESPONDING']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'alert_responding', 'alert_id' => $alert->id]);
    }

    /** Scenario 8: Responder can move RESPONDING → RESOLVED. */
    public function test_responder_can_move_responding_to_resolved(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/respond");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/resolve", ['resolution_note' => 'Student safe, false alarm.']);

        $response->assertStatus(200)->assertJson(['status' => 'RESOLVED']);

        $alert->refresh();
        $this->assertSame('Student safe, false alarm.', $alert->resolution_note);
        $this->assertSame($this->responder->id, $alert->resolved_by);
    }

    /** Scenario 9: Resolve requires resolution_note. */
    public function test_resolve_requires_resolution_note(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/respond");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/resolve", []);

        $response->assertStatus(422)->assertJsonValidationErrors('resolution_note');
    }

    /** Scenario 10: Cannot RESPOND before ACKNOWLEDGED. */
    public function test_cannot_respond_before_acknowledged(): void
    {
        $alert = $this->receivedAlert();

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/respond");

        $response->assertStatus(409)->assertJsonPath('current_status', 'RECEIVED');
    }

    /** Scenario 11: Cannot RESOLVE before RESPONDING. */
    public function test_cannot_resolve_before_responding(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/resolve", ['resolution_note' => 'n/a']);

        $response->assertStatus(409)->assertJsonPath('current_status', 'ACKNOWLEDGED');
    }

    /** Scenario 12: Cannot CANCEL a RESPONDING alert. */
    public function test_cannot_cancel_a_responding_alert(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/respond");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", ['cancellation_reason' => 'test']);

        $response->assertStatus(409)->assertJsonPath('current_status', 'RESPONDING');
    }

    /** Scenario 13: Student can cancel their own ACTIVE/RECEIVED alert. */
    public function test_student_can_cancel_their_own_received_alert(): void
    {
        $alert = $this->receivedAlert();

        $response = $this->actingAs($this->student, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", ['cancellation_reason' => 'Accidental trigger.']);

        $response->assertStatus(200)->assertJson(['status' => 'CANCELLED']);

        $alert->refresh();
        $this->assertSame($this->student->id, $alert->cancelled_by);
        $this->assertSame('Accidental trigger.', $alert->cancellation_reason);

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'alert_cancelled_by_user',
            'alert_id' => $alert->id,
        ]);
    }

    /** Scenario 14: Student cannot cancel after responder acknowledgement. */
    public function test_student_cannot_cancel_after_acknowledgement(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response = $this->actingAs($this->student, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", ['cancellation_reason' => 'Change of mind.']);

        // The student is neither the responder nor an admin, so
        // AlertAuthorization rejects this before the state machine is even
        // consulted — 403, not 409.
        $response->assertStatus(403);

        $alert->refresh();
        $this->assertSame(EmergencyAlert::STATUS_ACKNOWLEDGED, $alert->status);
    }

    /** Responder/admin CAN cancel an ACKNOWLEDGED alert (the other half of scenario 14's boundary). */
    public function test_responder_can_cancel_an_acknowledged_alert(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", ['cancellation_reason' => 'Confirmed false alarm.']);

        $response->assertStatus(200)->assertJson(['status' => 'CANCELLED']);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'alert_cancelled_by_responder',
            'alert_id' => $alert->id,
        ]);
    }

    /** Scenario 15: Cancellation requires cancellation_reason. */
    public function test_cancellation_requires_cancellation_reason(): void
    {
        $alert = $this->receivedAlert();

        $response = $this->actingAs($this->student, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", []);

        $response->assertStatus(422)->assertJsonValidationErrors('cancellation_reason');
    }

    /** Scenario 16 (broader check): every transition creates an audit log. */
    public function test_every_transition_creates_an_audit_log(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/respond");
        $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/resolve", ['resolution_note' => 'Resolved.']);

        $actions = \App\Models\AuditLog::where('alert_id', $alert->id)->pluck('action')->all();

        $this->assertContains('alert_received', $actions);
        $this->assertContains('alert_acknowledged', $actions);
        $this->assertContains('alert_responding', $actions);
        $this->assertContains('alert_resolved', $actions);
    }

    /** Never allow a backward transition (RESOLVED is terminal). */
    public function test_resolved_alert_cannot_transition_further(): void
    {
        $alert = $this->receivedAlert();
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/acknowledge");
        $this->actingAs($this->responder, 'sanctum')->postJson("/api/alerts/{$alert->id}/respond");
        $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/resolve", ['resolution_note' => 'Done.']);

        $response = $this->actingAs($this->responder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/cancel", ['cancellation_reason' => 'too late']);

        $response->assertStatus(409)->assertJsonPath('current_status', 'RESOLVED');
    }
}
