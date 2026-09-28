<?php

namespace Database\Factories;

use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'school_id' => School::factory(),
            'name' => $this->faker->name(),
            'email' => $this->faker->unique()->safeEmail(),
            'school_id_number' => $this->faker->bothify('S#####'),
            'password' => Hash::make('password123'),
            'role' => User::ROLE_STUDENT,
            'phone' => $this->faker->e164PhoneNumber(),
            'status' => 'active',
        ];
    }

    public function staff(): static
    {
        return $this->state(['role' => User::ROLE_STAFF]);
    }

    public function admin(): static
    {
        return $this->state(['role' => User::ROLE_ADMIN]);
    }

    /** Plain role=responder WITHOUT a responders row — for the one test that needs that gap. */
    public function responderRoleOnly(): static
    {
        return $this->state(['role' => User::ROLE_RESPONDER]);
    }
}
