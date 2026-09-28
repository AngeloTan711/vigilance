<?php

namespace App\Http\Requests;

use App\Models\EmergencyAlert;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAlertRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Role restriction (student/staff only) enforced by route middleware
        // (role:student,staff) — see routes/api.php.
        return true;
    }

    public function rules(): array
    {
        return [
            // Phase 3 brief §2: "latitude/longitude may both be null if GPS
            // is unavailable" — required_with each other enforces
            // both-or-neither rather than one without the other.
            'latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
            'accuracy' => ['nullable', 'numeric'],
            'activated_at' => ['required', 'date', 'before_or_equal:now'],
            // delivery_method must be CLOUD or SMS — PENDING/QUEUED must
            // never reach this endpoint (Phase 3 brief §2): those are
            // local-only mobile states for an attempt that hasn't
            // succeeded yet, and this endpoint is only reached once one has.
            'delivery_method' => ['required', Rule::in([
                EmergencyAlert::DELIVERY_METHOD_CLOUD,
                EmergencyAlert::DELIVERY_METHOD_SMS,
            ])],
            'message' => ['nullable', 'string', 'max:500'],
            'is_test' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'delivery_method.in' => 'delivery_method must be CLOUD or SMS — PENDING/QUEUED alerts cannot be submitted as delivered.',
        ];
    }
}
