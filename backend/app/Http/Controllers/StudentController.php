<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

// docs/ARCHITECTURE.md §4 GET /api/students — responder (own school only) or admin (all schools).
class StudentController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        if (!$user->isAdmin() && !$user->isResponder()) {
            abort(403, 'Only responders and admins may view the student/staff roster.');
        }

        $roles = $request->filled('role')
            ? array_map('trim', explode(',', $request->query('role')))
            : [User::ROLE_STUDENT, User::ROLE_STAFF];

        $query = User::query()->whereIn('role', $roles);

        if (!$user->isAdmin()) {
            // Responder is scoped to their own school — never client-supplied.
            $query->where('school_id', $user->responder->school_id);
        }

        return $query->orderBy('name')->paginate(25, ['id', 'name', 'email', 'school_id', 'role', 'status']);
    }
}
