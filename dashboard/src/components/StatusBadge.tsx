import type { AlertStatus } from '../api/types';

export default function StatusBadge({ status }: { status: AlertStatus }) {
  return <span className={`badge status-${status.toLowerCase()}`}>{status}</span>;
}
