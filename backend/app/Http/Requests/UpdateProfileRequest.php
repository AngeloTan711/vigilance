<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Auth middleware already guarantees a logged-in user; own-profile-only is structural (controller uses $request->user()).
    }

    public function rules(): array
    {
        $userId = $this->user()->id;

        return [
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'string', 'max:30'],
            'email' => ['sometimes', 'email', Rule::unique('users', 'email')->ignore($userId)],
            // role/school_id are intentionally absent — not user-editable,
            // per docs/ARCHITECTURE.md §4 PUT /profile.
        ];
    }
}
