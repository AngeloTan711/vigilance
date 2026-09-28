import { useCallback, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../api/client';
import AlertActions from '../components/AlertActions';
import ErrorBanner from '../components/ErrorBanner';
import StatusBadge from '../components/StatusBadge';
import { usePolling } from '../hooks/usePolling';
import { durationLabel, formatClock } from '../lib/time';
import type { Alert } from '../api/types';

const MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY as string | undefined;

export default function AlertDetailPage() {
  const { id } = useParams();
  const alertId = Number(id);
  const [actionError, setActionError] = useState<unknown>(null);
  const [override, setOverride] = useState<Alert | null>(null);

  const fetcher = useCallback(() => api.alert(alertId), [alertId]);
  const { data, error, loading, refresh } = usePolling(fetcher);

  const alert = override ?? data;

  if (loading && alert === null) return <p className="muted">Loading alert…</p>;
  if (error && alert === null) return <ErrorBanner error={error} />;
  if (alert === null) return null;

  const timeline: Array<[string, string | null, string | undefined]> = [
    ['Activated (device)', alert.activated_at, undefined],
    ['Received (server)', alert.received_at, undefined],
    ['Acknowledged', alert.acknowledged_at, alert.acknowledged_by?.name],
    ['Responding', alert.responded_at, alert.responded_by?.name],
    ['Resolved', alert.resolved_at, alert.resolved_by?.name],
    ['Cancelled', alert.cancelled_at, alert.cancelled_by?.name],
  ];

  const hasCoordinates = alert.latitude !== null && alert.longitude !== null;

  return (
    <section>
      <div className="page-head">
        <h2>
          <Link className="back" to="/">
            ←
          </Link>{' '}
          Alert #{alert.id} <StatusBadge status={alert.status} />
          {alert.is_test && <span className="badge test">TEST</span>}
        </h2>
        <span className="muted">School {alert.school_id} · reporter user {alert.user_id}</span>
      </div>

      <ErrorBanner error={actionError} />

      <div className="detail-grid">
        <div className="card">
          <h3>Response</h3>
          <AlertActions
            alert={alert}
            onDone={(updated) => {
              setOverride(updated);
              setActionError(null);
              void refresh();
            }}
            onError={(e) => {
              setActionError(e);
              setOverride(null);
              void refresh();
            }}
          />
          {alert.resolution_note && (
            <p className="note">
              <strong>Resolution note:</strong> {alert.resolution_note}
            </p>
          )}
          {alert.cancellation_reason && (
            <p className="note">
              <strong>Cancellation reason:</strong> {alert.cancellation_reason}
            </p>
          )}
        </div>

        <div className="card">
          <h3>Location</h3>
          {hasCoordinates ? (
            <>
              <p className="mono">
                {alert.latitude!.toFixed(6)}, {alert.longitude!.toFixed(6)}
                {alert.accuracy !== null && <span className="muted"> (±{alert.accuracy} m)</span>}
              </p>
              {MAPS_KEY ? (
                <iframe
                  title="Alert location"
                  className="map"
                  loading="lazy"
                  src={`https://www.google.com/maps/embed/v1/place?key=${MAPS_KEY}&q=${alert.latitude},${alert.longitude}`}
                />
              ) : (
                <p className="muted small">
                  Map rendering requires an external service (<code>VITE_GOOGLE_MAPS_API_KEY</code>);
                  no key is configured, so coordinates are shown instead.{' '}
                  <a
                    href={`https://www.openstreetmap.org/?mlat=${alert.latitude}&mlon=${alert.longitude}#map=18/${alert.latitude}/${alert.longitude}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    Open in map
                  </a>
                </p>
              )}
            </>
          ) : (
            <p className="muted">Location unavailable (GPS was not obtained on the device).</p>
          )}
          <h3>Delivery</h3>
          <p>
            Method <strong>{alert.delivery_method}</strong> · status{' '}
            <strong>{alert.delivery_status}</strong>
          </p>
          {alert.message && <p className="note">{alert.message}</p>}
        </div>

        <div className="card">
          <h3>Timeline</h3>
          <table className="timeline">
            <tbody>
              {timeline.map(([label, at, actor]) => (
                <tr key={label} className={at ? '' : 'pending'}>
                  <td>{label}</td>
                  <td>{formatClock(at)}</td>
                  <td className="muted">{actor ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="muted small">
            Received → closed:{' '}
            {durationLabel(alert.received_at, alert.resolved_at ?? alert.cancelled_at)}
          </p>
        </div>
      </div>
    </section>
  );
}
