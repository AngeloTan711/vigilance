import type { Alert, AuthUser, Page, Responder, RosterUser, School, Statistics } from './types';

const BASE_URL = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? '/api';
const TOKEN_KEY = 'vigilance.token';

/**
 * Typed error carrying the backend's approved error envelope
 * (`{ message, errors? }`, plus `current_status` on 409) so screens can react
 * to 403 / 409 / 422 distinctly instead of showing one generic failure.
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly errors?: Record<string, string[]>,
    readonly currentStatus?: string,
  ) {
    super(message);
  }

  fieldError(field: string): string | undefined {
    return this.errors?.[field]?.[0];
  }
}

export const tokenStore = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: (token: string) => localStorage.setItem(TOKEN_KEY, token),
  clear: () => localStorage.removeItem(TOKEN_KEY),
};

let onUnauthenticated: (() => void) | null = null;
export function setUnauthenticatedHandler(handler: () => void) {
  onUnauthenticated = handler;
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const token = tokenStore.get();

  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (response.status === 204) {
    return undefined as T;
  }

  const payload = await response.json().catch(() => ({}));

  if (!response.ok) {
    if (response.status === 401) {
      tokenStore.clear();
      onUnauthenticated?.();
    }

    throw new ApiError(
      response.status,
      (payload as { message?: string }).message ?? `Request failed (${response.status})`,
      (payload as { errors?: Record<string, string[]> }).errors,
      (payload as { current_status?: string }).current_status,
    );
  }

  return payload as T;
}

export interface AlertQuery {
  status?: string;
  include_test?: boolean;
  from?: string;
  to?: string;
  school_id?: number;
  page?: number;
}

function toQueryString(query: Record<string, unknown>): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && value !== '') {
      params.set(key, String(value));
    }
  }
  const qs = params.toString();
  return qs ? `?${qs}` : '';
}

interface RawPage<T> {
  data: T[];
  meta?: { current_page: number; last_page: number; total: number };
  current_page?: number;
  last_page?: number;
  total?: number;
}

function normalisePage<T>(raw: RawPage<T>): Page<T> {
  return {
    data: raw.data ?? [],
    currentPage: raw.meta?.current_page ?? raw.current_page ?? 1,
    lastPage: raw.meta?.last_page ?? raw.last_page ?? 1,
    total: raw.meta?.total ?? raw.total ?? raw.data?.length ?? 0,
  };
}

export const api = {
  login: (email: string, password: string) =>
    request<{ token: string; user: AuthUser }>('POST', '/login', { email, password }),

  logout: () => request<{ message: string }>('POST', '/logout'),

  profile: () => request<AuthUser>('GET', '/profile'),

  statistics: (schoolId?: number) =>
    request<Statistics>('GET', `/dashboard/statistics${toQueryString({ school_id: schoolId })}`),

  activeAlerts: (schoolId?: number, includeTest = false) =>
    request<Alert[]>(
      'GET',
      `/dashboard/active-alerts${toQueryString({ school_id: schoolId, include_test: includeTest ? 1 : undefined })}`,
    ),

  alerts: async (query: AlertQuery = {}) =>
    normalisePage(
      await request<RawPage<Alert>>(
        'GET',
        `/alerts${toQueryString({ ...query, include_test: query.include_test ? 1 : undefined })}`,
      ),
    ),

  alert: (id: number) => request<Alert>('GET', `/alerts/${id}`),

  acknowledge: (id: number) => request<Alert>('POST', `/alerts/${id}/acknowledge`),

  respond: (id: number) => request<Alert>('POST', `/alerts/${id}/respond`),

  resolve: (id: number, resolutionNote: string) =>
    request<Alert>('POST', `/alerts/${id}/resolve`, { resolution_note: resolutionNote }),

  cancel: (id: number, cancellationReason: string) =>
    request<Alert>('POST', `/alerts/${id}/cancel`, { cancellation_reason: cancellationReason }),

  students: async (role?: string, page?: number) =>
    normalisePage(await request<RawPage<RosterUser>>('GET', `/students${toQueryString({ role, page })}`)),

  responders: () => request<Responder[]>('GET', '/responders'),

  schools: () => request<School[]>('GET', '/schools'),
};
