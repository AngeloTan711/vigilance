<?php

namespace App\Http\Controllers;

use App\Models\Responder;

// docs/ARCHITECTURE.md §4 GET /api/responders — admin only.
class ResponderController extends Controller
{
    public function index()
    {
        $responders = Responder::with(['user:id,name,email', 'school:id,name'])->get();

        return $responders->map(fn (Responder $r) => [
            'id' => $r->id,
            'user' => ['id' => $r->user->id, 'name' => $r->user->name, 'email' => $r->user->email],
            'school' => ['id' => $r->school->id, 'name' => $r->school->name],
            'position' => $r->position,
            'is_available' => $r->is_available,
        ]);
    }
}
