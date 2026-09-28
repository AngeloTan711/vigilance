<?php

namespace App\Providers;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // docs/ARCHITECTURE.md §4 specifies bare objects for single-record
        // responses ("200 OK, updated alert object"), not a "data" envelope;
        // paginated collections keep their own data/meta/links structure.
        JsonResource::withoutWrapping();
    }
}
