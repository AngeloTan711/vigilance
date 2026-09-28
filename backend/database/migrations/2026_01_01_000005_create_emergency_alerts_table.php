<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2 (base columns) + §1.5 (acknowledged_by/responded_by/
// resolved_by/cancelled_by/cancelled_at/cancellation_reason/resolution_note)
// + §2.3 (delivery_method/delivery_status replacing the old single
// communication_method column). Since this is a fresh migration (not an
// ALTER TABLE against an already-deployed table), all of this is folded into
// one CREATE — the doc's ALTER statements describe the same end state.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('emergency_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users');
            $table->foreignId('school_id')->constrained('schools');

            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->float('accuracy')->nullable();

            $table->dateTime('activated_at');
            $table->dateTime('received_at')->nullable();
            $table->dateTime('acknowledged_at')->nullable();
            $table->dateTime('responded_at')->nullable();
            $table->dateTime('resolved_at')->nullable();
            $table->dateTime('cancelled_at')->nullable();

            $table->enum('status', [
                'ACTIVE', 'RECEIVED', 'ACKNOWLEDGED', 'RESPONDING', 'RESOLVED', 'CANCELLED',
            ])->default('ACTIVE');

            // §2.3 — kept as two separate fields, never merged.
            $table->enum('delivery_method', ['PENDING', 'CLOUD', 'SMS'])->default('PENDING');
            $table->enum('delivery_status', ['QUEUED', 'SENDING', 'DELIVERED', 'FAILED'])->default('QUEUED');

            $table->string('message', 500)->nullable();
            $table->boolean('is_test')->default(false);

            $table->foreignId('acknowledged_by')->nullable()->constrained('users');
            $table->foreignId('responded_by')->nullable()->constrained('users');
            $table->foreignId('resolved_by')->nullable()->constrained('users');
            $table->foreignId('cancelled_by')->nullable()->constrained('users');

            $table->string('resolution_note', 255)->nullable();
            $table->string('cancellation_reason', 255)->nullable();

            $table->timestamps();

            $table->index(['school_id', 'status']);
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('emergency_alerts');
    }
};
