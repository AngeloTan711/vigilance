<?php

namespace Database\Factories;

use App\Models\School;
use Illuminate\Database\Eloquent\Factories\Factory;

class SchoolFactory extends Factory
{
    protected $model = School::class;

    public function definition(): array
    {
        return [
            'name' => $this->faker->company().' High School',
            'address' => $this->faker->streetAddress(),
            'city' => $this->faker->city(),
            'status' => 'active',
        ];
    }
}
