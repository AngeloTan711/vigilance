<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Laravel Sanctum's standard token table. Normally published via
// `php artisan vendor:publish --tag=sanctum-migrations` — included directly
// here because this environment can't run that command (no PHP/Composer/
// network — see docs/PHASE3_STATUS.md). If a real `composer require
// laravel/sanctum` + vendor:publish is run and generates its own copy of
// this migration, delete one of the two to avoid a duplicate-table error.
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->morphs('tokenable');
            $table->string('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('personal_access_tokens');
    }
};
