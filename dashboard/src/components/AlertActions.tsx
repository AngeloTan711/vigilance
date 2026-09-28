import { useState } from 'react';
import { api } from '../api/client';
import type { Alert } from '../api/types';

/**
 * Which buttons exist follows the approved state machine (§1) exactly — no
 * transition is offered that the backend would refuse, and no transition the
 * backend allows is hidden. The server remains the authority: a 409 here
 * means another responder won the race, and the caller refreshes.
 */
export default function AlertActions({
  alert,
  onDone,
  onError,
}: {
  alert: Alert;
  onDone: (updated: Alert) => void;
  onError: (error: unknown) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [prompt, setPrompt] = useState<'resolve' | 'cancel' | null>(null);
  const [note, setNote] = useState('');

  const run = async (action: () => Promise<Alert>) => {
    setBusy(true);
    try {
      onDone(await action());
      setPrompt(null);
      setNote('');
    } catch (error) {
      onError(error);
    } finally {
      setBusy(false);
    }
  };

  if (alert.status === 'RESOLVED' || alert.status === 'CANCELLED') {
    return <p className="muted">This incident is closed. No further transitions are possible.</p>;
  }

  if (prompt !== null) {
    const isResolve = prompt === 'resolve';
    return (
      <div className="prompt">
        <label htmlFor="note">
          {isResolve ? 'Resolution note (required)' : 'Cancellation reason (required)'}
        </label>
        <textarea
          id="note"
          value={note}
          maxLength={255}
          onChange={(event) => setNote(event.target.value)}
          placeholder={
            isResolve
              ? 'Student located, met by school nurse.'
              : 'Confirmed false alarm after contacting the student.'
          }
        />
        <div className="row">
          <button
            className="btn primary"
            disabled={busy || note.trim() === ''}
            onClick={() =>
              void run(() =>
                isResolve ? api.resolve(alert.id, note.trim()) : api.cancel(alert.id, note.trim()),
              )
            }
          >
            {isResolve ? 'Resolve incident' : 'Cancel alert'}
          </button>
          <button className="btn subtle" disabled={busy} onClick={() => setPrompt(null)}>
            Back
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="row">
      {alert.status === 'RECEIVED' && (
        <button className="btn primary" disabled={busy} onClick={() => void run(() => api.acknowledge(alert.id))}>
          Acknowledge
        </button>
      )}
      {alert.status === 'ACKNOWLEDGED' && (
        <button className="btn primary" disabled={busy} onClick={() => void run(() => api.respond(alert.id))}>
          Respond
        </button>
      )}
      {alert.status === 'RESPONDING' && (
        <button className="btn primary" disabled={busy} onClick={() => setPrompt('resolve')}>
          Resolve…
        </button>
      )}
      {(alert.status === 'ACTIVE' || alert.status === 'RECEIVED' || alert.status === 'ACKNOWLEDGED') && (
        <button className="btn danger" disabled={busy} onClick={() => setPrompt('cancel')}>
          Cancel alert…
        </button>
      )}
    </div>
  );
}
