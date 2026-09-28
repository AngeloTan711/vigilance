<?php

namespace App\Http\Controllers;

use App\Models\School;

// docs/ARCHITECTURE.md §4 GET /api/schools — admin only.
class SchoolController extends Controller
{
    public function index()
    {
        return School::orderBy('name')->get(['id', 'name', 'address', 'city', 'status']);
    }
}
