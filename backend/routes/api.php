<?php

use App\Http\Controllers\Admin\ResponderProvisioningController;
use App\Http\Controllers\AlertController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\EmergencyContactController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ResponderController;
use App\Http\Controllers\SchoolController;
use App\Http\Controllers\StudentController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — mirrors docs/ARCHITECTURE.md §4 endpoint-for-endpoint.
|--------------------------------------------------------------------------
| Every route not under the "no auth" group runs through Sanctum's
| auth:sanctum guard. Role restriction beyond "authenticated" is enforced
| with the `role:` middleware (App\Http\Middleware\EnsureRole, aliased in
| bootstrap/app.php) — but role middleware is coarse access control only;
| finer-grained checks (school scope, alert ownership) happen inside the
| controllers via App\Services\AlertAuthorization, per
| docs/ARCHITECTURE.md §5 point 2 vs point 3.
*/

// --- No auth required ---
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);

// --- Authenticated (any role) ---
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/profile', [ProfileController::class, 'show']);
    Route::put('/profile', [ProfileController::class, 'update']);

    Route::get('/emergency-contacts', [EmergencyContactController::class, 'index']);
    Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
    Route::put('/emergency-contacts/{contact}', [EmergencyContactController::class, 'update']);
    Route::delete('/emergency-contacts/{contact}', [EmergencyContactController::class, 'destroy']);

    // GET /alerts/{alert} is reachable by the owning student/staff user too
    // (not just responder/admin) — enforced inside AlertController::show,
    // not by role middleware, since "the alerting user themself" isn't a
    // single role.
    Route::get('/alerts/{alert}', [AlertController::class, 'show']);

    // --- student/staff only ---
    Route::middleware('role:student,staff')->group(function () {
        Route::post('/alerts', [AlertController::class, 'store']);
    });

    // Cancel is reachable by the owner (student/staff) OR a responder/admin
    // of that school — role middleware can't express that union, so
    // AlertController::cancel + AlertAuthorization do the real check.
    Route::post('/alerts/{alert}/cancel', [AlertController::class, 'cancel']);

    // --- responder/admin only ---
    Route::middleware('role:responder,admin')->group(function () {
        Route::get('/alerts', [AlertController::class, 'index']);
        Route::post('/alerts/{alert}/acknowledge', [AlertController::class, 'acknowledge']);
        Route::post('/alerts/{alert}/respond', [AlertController::class, 'respond']);
        Route::post('/alerts/{alert}/resolve', [AlertController::class, 'resolve']);

        Route::get('/students', [StudentController::class, 'index']);

        Route::get('/dashboard/statistics', [DashboardController::class, 'statistics']);
        Route::get('/dashboard/active-alerts', [DashboardController::class, 'activeAlerts']);
    });

    // --- admin only ---
    Route::middleware('role:admin')->group(function () {
        Route::get('/responders', [ResponderController::class, 'index']);
        Route::get('/schools', [SchoolController::class, 'index']);

        // docs/ARCHITECTURE.md §5 — admin-only responder provisioning.
        // See ProvisionResponderRequest's doc comment: this endpoint was
        // named in §5 but never given a full §4-style spec entry, so its
        // exact request/response shape here is a documented extrapolation,
        // not something taken from an explicit approved contract.
        Route::post('/admin/responders', [ResponderProvisioningController::class, 'store']);
    });
});
