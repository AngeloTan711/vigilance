import { useCallback, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import ErrorBanner from '../components/ErrorBanner';
import StatusBadge from '../components/StatusBadge';
import { usePolling } from '../hooks/usePolling';
import { durationLabel, formatClock } from '../lib/time';
import type { AlertStatus } from '../api/types';

const STATUSES: AlertStatus[] = [
  'RECEIVED',
  'ACKNOWLEDGED',
  'RESPONDING',
  'RESOLVED',
  'CANCELLED',
];

export default function IncidentHistoryPage() {
  const [status, setStatus] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [includeTest, setIncludeTest] = useState(false);
  const [page, setPage] = useState(1);

  const fetcher = useCallback(
    () => api.alerts({ status: status || undefined, from: from || undefined, to: to || undefined, include_test: includeTest, page }),
    [status, from, to, includeTest, page],
  );

  // History is not time-critical: poll slowly so filters stay responsive.
  const { data, error, loading } = usePolling(fetcher, 60000);

  return (
    <section>
      <div className="page-head">
        <h2>Incident History</h2>
        <div className="row">
          <select className="filter" value={status} onChange={(event) => { setStatus(event.target.value); setPage(1); }}>
            <option value="">All statuses</option>
            {STATUSES.map((value) => (
              <option key={value} value={value}>
                {value}
              </option>
            ))}
          </select>
          <input className="filter" type="date" value={from} onChange={(event) => { setFrom(event.target.value); setPage(1); }} />
          <input className="filter" type="date" value={to} onChange={(event) => { setTo(event.target.value); setPage(1); }} />
          <label className="check">
            <input type="checkbox" checked={includeTest} onChange={(event) => { setIncludeTest(event.target.checked); setPage(1); }} />
            Include test
          </label>
        </div>
      </div>

      <ErrorBanner error={error} />
      {loading && data === null && <p className="muted">Loading incidents…</p>}

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>#</th>
              <th>Status</th>
              <th>Received</th>
              <th>Acknowledged by</th>
              <th>Closed by</th>
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            {data?.data.map((alert) => (
              <tr key={alert.id}>
                <td>
                  <Link to={`/alerts/${alert.id}`}>#{alert.id}</Link>
                </td>
                <td>
                  <StatusBadge status={alert.status} />
                </td>
                <td>{formatClock(alert.received_at)}</td>
                <td>{alert.acknowledged_by?.name ?? '—'}</td>
                <td>{alert.resolved_by?.name ?? alert.cancelled_by?.name ?? '—'}</td>
                <td>{durationLabel(alert.received_at, alert.resolved_at ?? alert.cancelled_at)}</td>
              </tr>
            ))}
            {data?.data.length === 0 && (
              <tr>
                <td colSpan={6} className="muted">
                  No incidents match these filters.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="row pager">
        <button className="btn subtle" disabled={page <= 1} onClick={() => setPage((value) => value - 1)}>
          Previous
        </button>
        <span className="muted">
          Page {data?.currentPage ?? page} of {data?.lastPage ?? '?'} · {data?.total ?? 0} incidents
        </span>
        <button
          className="btn subtle"
          disabled={data ? page >= data.lastPage : true}
          onClick={() => setPage((value) => value + 1)}
        >
          Next
        </button>
      </div>
    </section>
  );
}
