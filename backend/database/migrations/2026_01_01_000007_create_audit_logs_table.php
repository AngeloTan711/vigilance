<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2. user_id and alert_id are nullable — some entries
// (e.g. a failed login for an unknown email) have no resolvable user, and
// not every audit entry is alert-related (login/logout/profile updates).
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users');
            $table->string('action', 120);
            $table->foreignId('alert_id')->nullable()->constrained('emergency_alerts');
            $table->string('ip_address', 45)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index('alert_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
