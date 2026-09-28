<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;

/// Single place audit_logs rows get written, per docs/ARCHITECTURE.md §6:
/// "Do not silently modify an alert's history" — every important alert
/// action, plus login/logout/registration, goes through here rather than
/// each controller writing AuditLog::create() inline and risking drift.
class AuditLogger
{
    public function log(string $action, ?User $user, ?int $alertId, ?Request $request = null): void
    {
        AuditLog::create([
            'user_id' => $user?->id,
            'action' => $action,
            'alert_id' => $alertId,
            'ip_address' => $request?->ip(),
            'created_at' => now(),
        ]);
    }
}
