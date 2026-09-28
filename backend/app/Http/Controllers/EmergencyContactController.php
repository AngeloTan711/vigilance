<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreEmergencyContactRequest;
use App\Http\Requests\UpdateEmergencyContactRequest;
use App\Http\Resources\EmergencyContactResource;
use App\Models\EmergencyContact;
use Illuminate\Http\Request;

class EmergencyContactController extends Controller
{
    // docs/ARCHITECTURE.md §4 GET /api/emergency-contacts — own contacts only.
    public function index(Request $request)
    {
        $contacts = $request->user()->emergencyContacts()->orderBy('priority')->get();

        return EmergencyContactResource::collection($contacts);
    }

    // POST /api/emergency-contacts
    public function store(StoreEmergencyContactRequest $request)
    {
        $contact = $request->user()->emergencyContacts()->create($request->validated());

        return (new EmergencyContactResource($contact))->response()->setStatusCode(201);
    }

    // PUT /api/emergency-contacts/{contact}
    public function update(UpdateEmergencyContactRequest $request, EmergencyContact $contact)
    {
        $this->authorizeOwnership($request, $contact);

        $contact->update($request->validated());

        return new EmergencyContactResource($contact->refresh());
    }

    // DELETE /api/emergency-contacts/{contact}
    public function destroy(Request $request, EmergencyContact $contact)
    {
        $this->authorizeOwnership($request, $contact);

        $contact->delete();

        return response()->json(null, 204);
    }

    private function authorizeOwnership(Request $request, EmergencyContact $contact): void
    {
        // docs/ARCHITECTURE.md §4: 403 if not the owner, 404 if not found
        // (route-model binding already gives us 404 for a nonexistent id).
        if ($contact->user_id !== $request->user()->id) {
            abort(403, 'You do not own this contact.');
        }
    }
}
