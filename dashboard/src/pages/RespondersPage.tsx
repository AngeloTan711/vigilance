import { useCallback } from 'react';
import { api } from '../api/client';
import ErrorBanner from '../components/ErrorBanner';
import { usePolling } from '../hooks/usePolling';

/** Admin-only roster view (§4 GET /responders, §6 permission matrix). */
export default function RespondersPage() {
  const fetcher = useCallback(() => api.responders(), []);
  const { data, error, loading } = usePolling(fetcher, 120000);

  return (
    <section>
      <div className="page-head">
        <h2>Responders</h2>
      </div>

      <p className="muted small">
        <code>is_available</code> is advisory in the approved architecture — it does not block
        acknowledgement.
      </p>

      <ErrorBanner error={error} />
      {loading && data === null && <p className="muted">Loading responders…</p>}

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>School</th>
              <th>Position</th>
              <th>Available</th>
            </tr>
          </thead>
          <tbody>
            {data?.map((responder) => (
              <tr key={responder.id}>
                <td>{responder.user.name}</td>
                <td>{responder.user.email}</td>
                <td>{responder.school.name}</td>
                <td>{responder.position ?? '—'}</td>
                <td>{responder.is_available ? 'yes' : 'no'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
