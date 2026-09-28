<?php

namespace Tests\Feature;

use App\Models\School;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_register(): void
    {
        $school = School::factory()->create();

        $response = $this->postJson('/api/register', [
            'name' => 'Jane Doe',
            'school_id_number' => 'S1',
            'email' => 'jane@example.test',
            'phone' => '+10000000000',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'school_id' => $school->id,
            'role' => 'student',
        ]);

        $response->assertStatus(201)->assertJsonPath('user.role', 'student');
        $this->assertDatabaseHas('users', ['email' => 'jane@example.test', 'role' => 'student']);
    }

    /** docs/ARCHITECTURE.md §5: self-registration hard-rejects role=responder/admin regardless of input. */
    public function test_registration_rejects_responder_role(): void
    {
        $school = School::factory()->create();

        $response = $this->postJson('/api/register', [
            'name' => 'Sneaky',
            'email' => 'sneaky@example.test',
            'phone' => '+10000000000',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'school_id' => $school->id,
            'role' => 'responder',
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors('role');
        $this->assertDatabaseMissing('users', ['email' => 'sneaky@example.test']);
    }

    public function test_login_with_correct_credentials_succeeds(): void
    {
        $user = User::factory()->create(); // password123, per UserFactory

        $response = $this->postJson('/api/login', ['email' => $user->email, 'password' => 'password123']);

        $response->assertStatus(200)->assertJsonStructure(['token', 'user']);
    }

    public function test_login_with_wrong_password_returns_401(): void
    {
        $user = User::factory()->create();

        $response = $this->postJson('/api/login', ['email' => $user->email, 'password' => 'wrong-password']);

        $response->assertStatus(401);
    }
}
