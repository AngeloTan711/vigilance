<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * docs/ARCHITECTURE.md §5 mentions this endpoint (POST /api/admin/responders)
 * by name and behavior but — unlike every endpoint in §4 — was never given a
 * full request/response spec entry there. Rather than silently inventing
 * one without flagging it, this shape is a reasonable, consistent
 * extrapolation from the same conventions used everywhere else in the
 * approved spec (docs/PHASE3_STATUS.md calls this out explicitly as a gap
 * that should get a real §4-style entry if this endpoint's shape ever needs
 * to be locked down for a dashboard client to build against).
 */
class ProvisionResponderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // role:admin enforced by route middleware.
    }

    public function rules(): array
    {
        return [
            // Provisioning a brand-new responder account requires all of these.
            'name' => ['required_without:promote_user_id', 'string', 'max:255'],
            'email' => ['required_without:promote_user_id', 'email', 'unique:users,email'],
            'phone' => ['required_without:promote_user_id', 'string', 'max:30'],
            'password' => ['required_without:promote_user_id', Password::min(8)],
            'school_id' => ['required_without:promote_user_id', 'integer', 'exists:schools,id'],

            // Alternative: promote an existing staff user instead of
            // creating a new account (docs §5, point "promotes an existing
            // staff user").
            'promote_user_id' => ['required_without:name', 'integer', 'exists:users,id'],

            'position' => ['nullable', 'string', 'max:120'],
        ];
    }
}
