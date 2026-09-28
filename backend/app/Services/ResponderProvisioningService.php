<?php

namespace App\Services;

use App\Models\Responder;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * docs/ARCHITECTURE.md §5: the ONLY place a users.role='responder' row and
 * its matching responders row are created. There is no public registration
 * path to role=responder (RegisterRequest hard-rejects it) — this is
 * admin-only, called from Admin\ResponderController (Phase 3 scope: the
 * service + the model relationship enforcement; a full admin UI is Phase 4
 * dashboard territory, not built here).
 */
class ResponderProvisioningService
{
    public function provision(array $userAttributes, int $schoolId, ?string $position = null): User
    {
        return DB::transaction(function () use ($userAttributes, $schoolId, $position) {
            $user = User::create(array_merge($userAttributes, [
                'role' => User::ROLE_RESPONDER,
                'school_id' => $schoolId,
                'password' => Hash::make($userAttributes['password']),
            ]));

            Responder::create([
                'user_id' => $user->id,
                'school_id' => $schoolId,
                'position' => $position,
                'is_available' => true,
            ]);

            return $user->refresh();
        });
    }

    /** Promote an existing staff account to responder, same atomicity guarantee. */
    public function promote(User $staffUser, ?string $position = null): User
    {
        return DB::transaction(function () use ($staffUser, $position) {
            $staffUser->update(['role' => User::ROLE_RESPONDER]);

            Responder::firstOrCreate(
                ['user_id' => $staffUser->id],
                ['school_id' => $staffUser->school_id, 'position' => $position, 'is_available' => true],
            );

            return $staffUser->refresh();
        });
    }
}
