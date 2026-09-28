// Mirrors the Phase 3 API contract (docs/ARCHITECTURE.md §4) exactly. No
// status value, role or delivery enum is invented here — these are the same
// strings the backend enum columns hold.

export type AlertStatus =
  | 'ACTIVE'
  | 'RECEIVED'
  | 'ACKNOWLEDGED'
  | 'RESPONDING'
  | 'RESOLVED'
  | 'CANCELLED';

export type DeliveryMethod = 'PENDING' | 'CLOUD' | 'SMS';
export type DeliveryStatus = 'QUEUED' | 'SENDING' | 'DELIVERED' | 'FAILED';
export type Role = 'student' | 'staff' | 'responder' | 'admin';

export interface Actor {
  id: number;
  name: string;
}

export interface AuthUser {
  id: number;
  name: string;
  role: Role;
  school_id: number | null;
}

export interface Alert {
  id: number;
  user_id: number;
  school_id: number;
  latitude: number | null;
  longitude: number | null;
  accuracy: number | null;
  status: AlertStatus;
  delivery_method: DeliveryMethod;
  delivery_status: DeliveryStatus;
  message: string | null;
  is_test: boolean;
  activated_at: string | null;
  received_at: string | null;
  acknowledged_at: string | null;
  responded_at: string | null;
  resolved_at: string | null;
  cancelled_at: string | null;
  acknowledged_by?: Actor | null;
  responded_by?: Actor | null;
  resolved_by?: Actor | null;
  cancelled_by?: Actor | null;
  resolution_note: string | null;
  cancellation_reason: string | null;
}

/**
 * Normalised page shape. The backend emits two different paginator layouts:
 * `GET /alerts` wraps an API Resource collection (`{ data, links, meta }`)
 * while `GET /students` returns a raw paginator with the page fields at the
 * top level. `client.ts` flattens both into this one shape.
 */
export interface Page<T> {
  data: T[];
  currentPage: number;
  lastPage: number;
  total: number;
}

export interface Statistics {
  active: number;
  acknowledged: number;
  responding: number;
  resolved_today: number;
}

export interface Responder {
  id: number;
  position: string | null;
  is_available: boolean;
  user: { id: number; name: string; email: string };
  school: { id: number; name: string };
}

export interface RosterUser {
  id: number;
  name: string;
  email: string;
  school_id: number;
  role: Role;
  status: string;
}

export interface School {
  id: number;
  name: string;
}
