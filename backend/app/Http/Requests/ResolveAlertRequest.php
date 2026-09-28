<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ResolveAlertRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Responder/school-scope authorization is checked in the controller via AlertAuthorization, before validation matters.
    }

    public function rules(): array
    {
        return [
            // docs/ARCHITECTURE.md §1.5 / Phase 3 brief §5: resolution_note
            // is required — an incident can never be closed with no record
            // of how.
            'resolution_note' => ['required', 'string', 'max:255'],
        ];
    }
}
