import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';
import AlertCard from '../components/AlertCard';
import ErrorBanner from '../components/ErrorBanner';
import { useAuth } from '../auth/AuthContext';
import { usePolling } from '../hooks/usePolling';
import type { Alert, School, Statistics } from '../api/types';

export default function ActiveAlertsPage() {
  const { user } = useAuth();
  const [includeTest, setIncludeTest] = useState(false);
  const [schoolId, setSchoolId] = useState<string>('');
  const [schools, setSchools] = useState<School[]>([]);

  // GET /schools is admin-only, so responders never request it.
  useEffect(() => {
    if (user?.role !== 'admin') return;
    api.schools().then(setSchools).catch(() => setSchools([]));
  }, [user?.role]);

  const scope = user?.role === 'admin' && schoolId !== '' ? Number(schoolId) : undefined;

  const fetcher = useCallback(
    async (): Promise<{ alerts: Alert[]; statistics: Statistics }> => {
      const [alerts, statistics] = await Promise.all([
        api.activeAlerts(scope, includeTest),
        api.statistics(scope),
      ]);
      return { alerts, statistics };
    },
    [scope, includeTest],
  );

  const { data, error, loading } = usePolling(fetcher);

  return (
    <section>
      <div className="page-head">
        <h2>Active Alerts</h2>
        <div className="row">
          {user?.role === 'admin' && (
            <select
              className="filter"
              value={schoolId}
              onChange={(event) => setSchoolId(event.target.value)}
            >
              <option value="">All schools</option>
              {schools.map((school) => (
                <option key={school.id} value={school.id}>
                  {school.name}
                </option>
              ))}
            </select>
          )}
          <label className="check">
            <input
              type="checkbox"
              checked={includeTest}
              onChange={(event) => setIncludeTest(event.target.checked)}
            />
            Include test alerts
          </label>
        </div>
      </div>

      <p className="muted small">
        Live view refreshes automatically (polling — push notifications require an external
        service and are not part of this build).
      </p>

      <ErrorBanner error={error} />

      {data && (
        <div className="stats">
          <div className="stat">
            <span className="stat-value">{data.statistics.active}</span>
            <span className="stat-label">Awaiting acknowledgement</span>
          </div>
          <div className="stat">
            <span className="stat-value">{data.statistics.acknowledged}</span>
            <span className="stat-label">Acknowledged</span>
          </div>
          <div className="stat">
            <span className="stat-value">{data.statistics.responding}</span>
            <span className="stat-label">Responding</span>
          </div>
          <div className="stat">
            <span className="stat-value">{data.statistics.resolved_today}</span>
            <span className="stat-label">Resolved today</span>
          </div>
        </div>
      )}

      {loading && data === null && <p className="muted">Loading alerts…</p>}

      {data && data.alerts.length === 0 && (
        <div className="card empty">No active alerts. All clear.</div>
      )}

      <div className="grid">
        {data?.alerts.map((alert) => (
          <AlertCard key={alert.id} alert={alert} />
        ))}
      </div>
    </section>
  );
}
