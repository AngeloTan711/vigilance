<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// docs/ARCHITECTURE.md §2 — users table. deleted_at implements the soft-delete
// policy from §16 (never hard-delete a user record).
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('school_id')->constrained('schools');
            $table->string('name');
            $table->string('email')->unique();
            $table->string('school_id_number', 100)->nullable();
            $table->string('password');
            $table->enum('role', ['student', 'staff', 'responder', 'admin'])->default('student');
            $table->string('phone', 30)->nullable();
            $table->enum('status', ['active', 'inactive', 'suspended'])->default('active');
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['school_id', 'role']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
