import { Link } from 'react-router-dom';
import StatusBadge from './StatusBadge';
import type { Alert } from '../api/types';
import { formatClock, sinceLabel } from '../lib/time';

export default function AlertCard({ alert }: { alert: Alert }) {
  return (
    <Link className={`card alert-card status-border-${alert.status.toLowerCase()}`} to={`/alerts/${alert.id}`}>
      <div className="alert-card-head">
        <span className="alert-id">#{alert.id}</span>
        <StatusBadge status={alert.status} />
        {alert.is_test && <span className="badge test">TEST</span>}
      </div>
      <div className="alert-card-body">
        <div className="elapsed">{sinceLabel(alert.received_at ?? alert.activated_at)}</div>
        <div className="muted">
          Activated {formatClock(alert.activated_at)} · {alert.delivery_method} /{' '}
          {alert.delivery_status}
        </div>
        <div className="muted">
          {alert.latitude !== null && alert.longitude !== null
            ? `${alert.latitude.toFixed(5)}, ${alert.longitude.toFixed(5)}`
            : 'Location unavailable'}
        </div>
        {alert.acknowledged_by && (
          <div className="muted">Acknowledged by {alert.acknowledged_by.name}</div>
        )}
      </div>
    </Link>
  );
}
