import { ApiError } from '../api/client';

/**
 * Renders the backend's approved error envelope. 409 carries `current_status`
 * (the dashboard's resync signal per §4), 422 carries per-field `errors`.
 */
export default function ErrorBanner({ error }: { error: unknown }) {
  if (!error) return null;

  const apiError = error instanceof ApiError ? error : null;
  const fieldErrors = apiError?.errors
    ? Object.entries(apiError.errors).flatMap(([field, messages]) =>
        messages.map((message) => `${field}: ${message}`),
      )
    : [];

  return (
    <div className="banner error">
      <strong>{apiError ? `${apiError.status} — ` : ''}</strong>
      {(error as Error).message}
      {apiError?.currentStatus && (
        <span className="muted"> (alert is now {apiError.currentStatus} — list refreshed)</span>
      )}
      {fieldErrors.length > 0 && (
        <ul>
          {fieldErrors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
