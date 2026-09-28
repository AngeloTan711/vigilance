<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CancelAlertRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Required for both owner-cancel and responder/admin-cancel —
            // docs/ARCHITECTURE.md §1.3: "cancellation without a reason is
            // rejected by validation."
            'cancellation_reason' => ['required', 'string', 'max:255'],
        ];
    }
}
