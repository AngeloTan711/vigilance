<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2 + §5. A responder is users.role='responder' AND a
// matching row here — both created atomically by ResponderProvisioningService,
// never independently (see app/Services/ResponderProvisioningService.php).
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('responders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users');
            $table->foreignId('school_id')->constrained('schools');
            $table->string('position', 120)->nullable();
            $table->boolean('is_available')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('responders');
    }
};
