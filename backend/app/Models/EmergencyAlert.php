<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EmergencyAlert extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'school_id', 'latitude', 'longitude', 'accuracy',
        'activated_at', 'received_at', 'acknowledged_at', 'responded_at',
        'resolved_at', 'cancelled_at', 'status', 'delivery_method',
        'delivery_status', 'message', 'is_test', 'acknowledged_by',
        'responded_by', 'resolved_by', 'cancelled_by', 'resolution_note',
        'cancellation_reason',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'accuracy' => 'float',
        'activated_at' => 'datetime',
        'received_at' => 'datetime',
        'acknowledged_at' => 'datetime',
        'responded_at' => 'datetime',
        'resolved_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'is_test' => 'boolean',
    ];

    // Status values — docs/ARCHITECTURE.md §1. Kept as string constants
    // (matching the plain MySQL ENUM column) rather than a PHP 8.1 enum
    // class, so AlertStateMachine's transition table (see
    // app/Services/AlertStateMachine.php) stays a simple, readable array.
    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_RECEIVED = 'RECEIVED';
    public const STATUS_ACKNOWLEDGED = 'ACKNOWLEDGED';
    public const STATUS_RESPONDING = 'RESPONDING';
    public const STATUS_RESOLVED = 'RESOLVED';
    public const STATUS_CANCELLED = 'CANCELLED';

    // Delivery — docs/ARCHITECTURE.md §2/§2.3. Deliberately two separate
    // concepts/columns; never merge these into one field or one enum.
    public const DELIVERY_METHOD_PENDING = 'PENDING';
    public const DELIVERY_METHOD_CLOUD = 'CLOUD';
    public const DELIVERY_METHOD_SMS = 'SMS';

    public const DELIVERY_STATUS_QUEUED = 'QUEUED';
    public const DELIVERY_STATUS_SENDING = 'SENDING';
    public const DELIVERY_STATUS_DELIVERED = 'DELIVERED';
    public const DELIVERY_STATUS_FAILED = 'FAILED';

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function school(): BelongsTo
    {
        return $this->belongsTo(School::class);
    }

    public function acknowledgedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'acknowledged_by');
    }

    public function respondedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'responded_by');
    }

    public function resolvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by');
    }

    public function cancelledBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    public function deliveryAttempts(): HasMany
    {
        return $this->hasMany(AlertDeliveryAttempt::class);
    }

    public function auditLogs(): HasMany
    {
        return $this->hasMany(AuditLog::class, 'alert_id');
    }
}
