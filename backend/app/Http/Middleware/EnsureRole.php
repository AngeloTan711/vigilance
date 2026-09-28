<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/// Route-level role gate, registered as 'role' in bootstrap/app.php, used as
/// role:student,staff / role:responder / role:admin etc. This is coarse
/// access control only (§5 point 2 of docs/ARCHITECTURE.md) — it does NOT
/// replace the finer-grained school-scope check that AlertAuthorization
/// does for individual alert actions. Never trusts anything the client
/// claims about its own role; reads $request->user()->role, which comes
/// from the authenticated Sanctum token's underlying DB record.
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        if (!in_array($user->role, $roles, true)) {
            return response()->json(['message' => 'Forbidden: insufficient role.'], 403);
        }

        return $next($request);
    }
}
