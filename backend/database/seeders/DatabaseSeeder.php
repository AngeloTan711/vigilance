<?php

namespace Database\Seeders;

use App\Models\School;
use App\Models\User;
use App\Services\ResponderProvisioningService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Seeds the minimum needed for Phase 2's mobile app to be usable against a
 * fresh backend, and for the Phase 3 test suite's manual/exploratory use:
 * - School id=1, matching mobile/PHASE2_STATUS.md's documented known
 *   limitation (registration form defaults to school_id=1 until a public
 *   schools-lookup endpoint exists).
 * - One student, one responder (school 1), one admin — enough to exercise
 *   the full lifecycle in §7's worked example by hand via Postman/curl.
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $school = School::create([
            'name' => 'Sample High School',
            'address' => '123 Example St',
            'city' => 'Cogan',
            'status' => 'active',
        ]);

        $student = User::create([
            'school_id' => $school->id,
            'name' => 'Jane Doe',
            'email' => 'jane.doe@example.edu',
            'school_id_number' => 'S12345',
            'password' => Hash::make('password123'),
            'role' => User::ROLE_STUDENT,
            'phone' => '+639171234567',
            'status' => 'active',
        ]);

        app(ResponderProvisioningService::class)->provision(
            userAttributes: [
                'name' => 'Mr. Santos',
                'email' => 'santos@example.edu',
                'phone' => '+639179876543',
                'password' => 'password123',
                'school_id_number' => null,
            ],
            schoolId: $school->id,
            position: 'School Security',
        );

        User::create([
            'school_id' => $school->id,
            'name' => 'System Admin',
            'email' => 'admin@example.edu',
            'school_id_number' => null,
            'password' => Hash::make('password123'),
            'role' => User::ROLE_ADMIN,
            'phone' => null,
            'status' => 'active',
        ]);

        $this->command?->info("Seeded school id={$school->id}, student id={$student->id} (jane.doe@example.edu / password123), responder (santos@example.edu / password123), admin (admin@example.edu / password123).");
    }
}
