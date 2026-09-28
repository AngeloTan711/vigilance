<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2. Hard-deletable (not a sensitive incident record,
// per the approved API spec's DELETE /emergency-contacts/{id}).
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('name');
            $table->string('phone', 30);
            $table->string('relationship', 100)->nullable();
            $table->unsignedTinyInteger('priority')->default(1);
            $table->timestamps();

            $table->index('user_id');
            // §Add emergency-contacts POST validation: priority must be unique
            // per user (server rejects duplicates rather than silently
            // reordering — approved spec, POST /emergency-contacts).
            $table->unique(['user_id', 'priority']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('emergency_contacts');
    }
};
