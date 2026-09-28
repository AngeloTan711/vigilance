<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProvisionResponderRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\ResponderProvisioningService;

/**
 * docs/ARCHITECTURE.md §5: the only path that can create a
 * users.role='responder' row — always paired atomically with a `responders`
 * row via ResponderProvisioningService. Route-gated to role:admin.
 */
class ResponderProvisioningController extends Controller
{
    public function __construct(private readonly ResponderProvisioningService $provisioning)
    {
    }

    public function store(ProvisionResponderRequest $request)
    {
        if ($request->filled('promote_user_id')) {
            $staffUser = User::findOrFail($request->integer('promote_user_id'));
            $user = $this->provisioning->promote($staffUser, $request->input('position'));

            return (new UserResource($user))->response()->setStatusCode(200);
        }

        $user = $this->provisioning->provision(
            userAttributes: $request->only(['name', 'email', 'phone', 'password', 'school_id_number']),
            schoolId: $request->integer('school_id'),
            position: $request->input('position'),
        );

        return (new UserResource($user))->response()->setStatusCode(201);
    }
}
