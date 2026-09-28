<?php

namespace App\Http\Requests;

use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'school_id_number' => ['nullable', 'string', 'max:100'],
            'email' => ['required', 'email', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'school_id' => ['required', 'integer', 'exists:schools,id'],
            // docs/ARCHITECTURE.md §4 POST /register: self-registration is
            // student/staff ONLY — role=responder/admin is rejected here
            // regardless of what's submitted, no matter what the client
            // sends. Responder accounts are provisioned exclusively via
            // ResponderProvisioningService (admin-only, §5).
            'role' => ['required', Rule::in([User::ROLE_STUDENT, User::ROLE_STAFF])],
        ];
    }

    public function messages(): array
    {
        return [
            'role.in' => 'Self-registration is only available for student and staff accounts.',
        ];
    }
}
