<?php

namespace App\Http\Controllers;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AuditLogger;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function __construct(private readonly AuditLogger $audit)
    {
    }

    // docs/ARCHITECTURE.md §4 POST /api/login
    public function login(LoginRequest $request)
    {
        $user = User::where('email', $request->string('email'))->first();

        if (!$user || !Hash::check($request->string('password'), $user->password)) {
            $this->audit->log('login_failed', $user, null, $request);

            // Manual response rather than ValidationException, to guarantee
            // the exact approved error envelope
            // ({"message","errors"}) at the approved 401 status — Laravel's
            // ValidationException always renders 422, which is correct for
            // field-level validation failures but wrong for "wrong
            // credentials", per docs/ARCHITECTURE.md §4 POST /login (401).
            return response()->json([
                'message' => 'Invalid credentials',
                'errors' => ['email' => ['Invalid credentials']],
            ], 401);
        }

        $token = $user->createToken('vigilance-mobile')->plainTextToken;

        $this->audit->log('login_success', $user, null, $request);

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user),
        ]);
    }

    // docs/ARCHITECTURE.md §4 POST /api/register — student/staff self-service only.
    public function register(RegisterRequest $request)
    {
        $user = User::create([
            'name' => $request->string('name'),
            'school_id_number' => $request->input('school_id_number'),
            'email' => $request->string('email'),
            'phone' => $request->string('phone'),
            'password' => Hash::make($request->string('password')),
            'school_id' => $request->integer('school_id'),
            'role' => $request->string('role'), // validated to student|staff only by RegisterRequest
            'status' => 'active',
        ]);

        $token = $user->createToken('vigilance-mobile')->plainTextToken;

        $this->audit->log('user_registered', $user, null, $request);

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user),
        ], 201);
    }

    // docs/ARCHITECTURE.md §4 POST /api/logout
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        $this->audit->log('logout', $request->user(), null, $request);

        return response()->json(['message' => 'Logged out']);
    }
}
