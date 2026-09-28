<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreEmergencyContactRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'relationship' => ['nullable', 'string', 'max:100'],
            // docs/ARCHITECTURE.md §4 POST /emergency-contacts: priority
            // must be unique per user — server REJECTS a duplicate rather
            // than silently reordering the user's other contacts.
            'priority' => [
                'required', 'integer', 'min:1',
                Rule::unique('emergency_contacts', 'priority')->where('user_id', $this->user()->id),
            ],
        ];
    }
}
