<?php

namespace Tests\Feature;

use App\Models\EmergencyAlert;
use App\Models\School;
use App\Models\User;
use App\Services\ResponderProvisioningService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SchoolScopeTest extends TestCase
{
    use RefreshDatabase;

    private function makeSchoolWithAlert(): array
    {
        $school = School::factory()->create();
        $student = User::factory()->for($school)->create();
        $responder = app(ResponderProvisioningService::class)->provision(
            userAttributes: [
                'name' => 'R', 'email' => uniqid().'@example.test',
                'phone' => '+10000000000', 'password' => 'password123',
            ],
            schoolId: $school->id,
        );

        $alert = EmergencyAlert::create([
            'user_id' => $student->id,
            'school_id' => $school->id,
            'activated_at' => now(),
            'received_at' => now(),
            'status' => EmergencyAlert::STATUS_RECEIVED,
            'delivery_method' => 'CLOUD',
            'delivery_status' => 'DELIVERED',
        ]);

        return compact('school', 'student', 'responder', 'alert');
    }

    /** Scenario 3: Responder can view alerts from their own school. */
    public function test_responder_can_view_alerts_from_own_school(): void
    {
        $a = $this->makeSchoolWithAlert();

        $response = $this->actingAs($a['responder'], 'sanctum')->getJson('/api/alerts');

        $response->assertStatus(200);
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertContains($a['alert']->id, $ids);
    }

    /** Scenario 4: Responder cannot view another school's alerts. */
    public function test_responder_cannot_view_another_schools_alerts(): void
    {
        $schoolA = $this->makeSchoolWithAlert();
        $schoolB = $this->makeSchoolWithAlert();

        // List endpoint: school B's responder never sees school A's alert.
        $listResponse = $this->actingAs($schoolB['responder'], 'sanctum')->getJson('/api/alerts');
        $ids = collect($listResponse->json('data'))->pluck('id')->all();
        $this->assertNotContains($schoolA['alert']->id, $ids);

        // Direct single-alert access: 403.
        $showResponse = $this->actingAs($schoolB['responder'], 'sanctum')
            ->getJson("/api/alerts/{$schoolA['alert']->id}");
        $showResponse->assertStatus(403);

        // Acting on it (acknowledge) is also rejected with 403, not silently applied.
        $ackResponse = $this->actingAs($schoolB['responder'], 'sanctum')
            ->postJson("/api/alerts/{$schoolA['alert']->id}/acknowledge");
        $ackResponse->assertStatus(403);

        $schoolA['alert']->refresh();
        $this->assertSame(EmergencyAlert::STATUS_RECEIVED, $schoolA['alert']->status);
    }

    /** Scenario 18: Admin school-scope permissions work correctly (admin sees/acts across all schools). */
    public function test_admin_can_view_and_act_across_schools(): void
    {
        $schoolA = $this->makeSchoolWithAlert();
        $schoolB = $this->makeSchoolWithAlert();
        $admin = User::factory()->for($schoolA['school'])->admin()->create();

        $listResponse = $this->actingAs($admin, 'sanctum')->getJson('/api/alerts');
        $ids = collect($listResponse->json('data'))->pluck('id')->all();
        $this->assertContains($schoolA['alert']->id, $ids);
        $this->assertContains($schoolB['alert']->id, $ids);

        $showResponse = $this->actingAs($admin, 'sanctum')->getJson("/api/alerts/{$schoolB['alert']->id}");
        $showResponse->assertStatus(200);

        $ackResponse = $this->actingAs($admin, 'sanctum')
            ->postJson("/api/alerts/{$schoolB['alert']->id}/acknowledge");
        $ackResponse->assertStatus(200);
    }

    /** A role=responder user with no matching `responders` record is rejected, not silently passed (docs §5 point 3). */
    public function test_role_responder_without_responder_record_is_rejected(): void
    {
        $school = School::factory()->create();
        $student = User::factory()->for($school)->create();
        $alert = EmergencyAlert::create([
            'user_id' => $student->id, 'school_id' => $school->id,
            'activated_at' => now(), 'received_at' => now(),
            'status' => EmergencyAlert::STATUS_RECEIVED,
            'delivery_method' => 'CLOUD', 'delivery_status' => 'DELIVERED',
        ]);

        $brokenResponder = User::factory()->for($school)->responderRoleOnly()->create();

        $response = $this->actingAs($brokenResponder, 'sanctum')
            ->postJson("/api/alerts/{$alert->id}/acknowledge");

        $response->assertStatus(403);
    }
}
