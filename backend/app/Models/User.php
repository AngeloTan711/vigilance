<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, SoftDeletes;

    protected $fillable = [
        'school_id', 'name', 'email', 'school_id_number', 'password',
        'role', 'phone', 'status',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'password' => 'hashed',
    ];

    // Roles — kept as plain string constants rather than a PHP enum so this
    // stays trivially compatible with a plain MySQL ENUM column; the four
    // values mirror docs/ARCHITECTURE.md §2 exactly.
    public const ROLE_STUDENT = 'student';
    public const ROLE_STAFF = 'staff';
    public const ROLE_RESPONDER = 'responder';
    public const ROLE_ADMIN = 'admin';

    public function school(): BelongsTo
    {
        return $this->belongsTo(School::class);
    }

    public function responder(): HasOne
    {
        return $this->hasOne(Responder::class);
    }

    public function emergencyContacts(): HasMany
    {
        return $this->hasMany(EmergencyContact::class);
    }

    public function emergencyAlerts(): HasMany
    {
        return $this->hasMany(EmergencyAlert::class);
    }

    public function isResponder(): bool
    {
        // §5 of docs/ARCHITECTURE.md: role AND a matching responders row are
        // both required — role alone is not sufficient. This is the single
        // enforcement point every controller/service should call instead of
        // checking `role === 'responder'` directly.
        return $this->role === self::ROLE_RESPONDER && $this->responder()->exists();
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }
}
