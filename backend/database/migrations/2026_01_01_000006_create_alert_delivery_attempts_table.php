<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2.2 — preserves the full CLOUD→fail→SMS delivery
// history that a single delivery_method/delivery_status pair on
// emergency_alerts can't hold on its own.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alert_delivery_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('emergency_alert_id')->constrained('emergency_alerts')->cascadeOnDelete();
            $table->enum('method', ['CLOUD', 'SMS']);
            $table->enum('status', ['SENDING', 'DELIVERED', 'FAILED']);
            $table->dateTime('attempted_at');
            $table->string('error_message', 255)->nullable();
            $table->timestamps();

            $table->index('emergency_alert_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alert_delivery_attempts');
    }
};
