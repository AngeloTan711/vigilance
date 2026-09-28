<?php

use App\Http\Middleware\EnsureRole;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

/*
|--------------------------------------------------------------------------
| Application Bootstrap (Laravel 11 style)
|--------------------------------------------------------------------------
| This targets Laravel 11's bootstrap/app.php convention (no app/Http/
| Kernel.php). If this code is instead layered onto a Laravel 10 skeleton,
| move the `role` middleware alias registration into
| app/Http/Kernel.php's $routeMiddleware array instead — see
| docs/PHASE3_STATUS.md for the exact note on this environment/version
| assumption.
*/
return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'role' => EnsureRole::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Deliberately minimal: Laravel's default JSON rendering already
        // produces the approved error envelope for the exception types this
        // API actually throws —
        //   ValidationException  -> 422 {"message","errors"}
        //   AuthenticationException -> 401 {"message"}
        //   AuthorizationException  -> 403 {"message"} (thrown by
        //       AlertAuthorization, per docs/ARCHITECTURE.md §5/§9)
        //   ModelNotFoundException  -> 404 {"message"} (route-model binding)
        // InvalidAlertTransitionException (-> 409) is caught locally inside
        // AlertController::handleTransition rather than here, so the 409
        // body can include `current_status` alongside `message` — see
        // app/Exceptions/InvalidAlertTransitionException.php.
    })->create();
