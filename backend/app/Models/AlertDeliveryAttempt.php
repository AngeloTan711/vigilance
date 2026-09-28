<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AlertDeliveryAttempt extends Model
{
    use HasFactory;

    protected $fillable = ['emergency_alert_id', 'method', 'status', 'attempted_at', 'error_message'];

    protected $casts = [
        'attempted_at' => 'datetime',
    ];

    public function alert(): BelongsTo
    {
        return $this->belongsTo(EmergencyAlert::class, 'emergency_alert_id');
    }
}
