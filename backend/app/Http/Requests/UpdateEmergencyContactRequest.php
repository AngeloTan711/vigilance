<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateEmergencyContactRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Ownership is checked in the controller (403 if not owner) before this runs against the right record.
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'string', 'max:30'],
            'relationship' => ['sometimes', 'nullable', 'string', 'max:100'],
            'priority' => [
                'sometimes', 'integer', 'min:1',
                Rule::unique('emergency_contacts', 'priority')
                    ->where('user_id', $this->user()->id)
                    ->ignore($this->route('contact')),
            ],
        ];
    }
}
