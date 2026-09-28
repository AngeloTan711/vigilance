<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Services\AuditLogger;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function __construct(private readonly AuditLogger $audit)
    {
    }

    // docs/ARCHITECTURE.md §4 GET /api/profile — own profile only, always
    // (there is no id parameter to this route; it's always $request->user()).
    public function show(Request $request)
    {
        return new UserResource($request->user());
    }

    // docs/ARCHITECTURE.md §4 PUT /api/profile
    public function update(UpdateProfileRequest $request)
    {
        $user = $request->user();
        $user->update($request->only(['name', 'phone', 'email']));

        $this->audit->log('profile_updated', $user, null, $request);

        return new UserResource($user->refresh());
    }
}
