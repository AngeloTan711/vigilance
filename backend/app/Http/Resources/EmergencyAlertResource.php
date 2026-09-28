<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/// docs/ARCHITECTURE.md §4 GET /alerts/{id}: full alert detail including
/// status, delivery_method/delivery_status, every timestamp, and
/// acknowledged_by/responded_by/resolved_by/cancelled_by each expanded to
/// {id, name} (not just a bare user id).
class EmergencyAlertResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'school_id' => $this->school_id,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'accuracy' => $this->accuracy,
            'status' => $this->status,
            'delivery_method' => $this->delivery_method,
            'delivery_status' => $this->delivery_status,
            'message' => $this->message,
            'is_test' => $this->is_test,
            'activated_at' => $this->activated_at?->toIso8601String(),
            'received_at' => $this->received_at?->toIso8601String(),
            'acknowledged_at' => $this->acknowledged_at?->toIso8601String(),
            'responded_at' => $this->responded_at?->toIso8601String(),
            'resolved_at' => $this->resolved_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'acknowledged_by' => $this->whenLoaded('acknowledgedBy', fn () => $this->acknowledgedBy ? [
                'id' => $this->acknowledgedBy->id, 'name' => $this->acknowledgedBy->name,
            ] : null),
            'responded_by' => $this->whenLoaded('respondedBy', fn () => $this->respondedBy ? [
                'id' => $this->respondedBy->id, 'name' => $this->respondedBy->name,
            ] : null),
            'resolved_by' => $this->whenLoaded('resolvedBy', fn () => $this->resolvedBy ? [
                'id' => $this->resolvedBy->id, 'name' => $this->resolvedBy->name,
            ] : null),
            'cancelled_by' => $this->whenLoaded('cancelledBy', fn () => $this->cancelledBy ? [
                'id' => $this->cancelledBy->id, 'name' => $this->cancelledBy->name,
            ] : null),
            'resolution_note' => $this->resolution_note,
            'cancellation_reason' => $this->cancellation_reason,
        ];
    }
}
