import { useCallback, useState } from 'react';
import { api } from '../api/client';
import ErrorBanner from '../components/ErrorBanner';
import { usePolling } from '../hooks/usePolling';

export default function RosterPage() {
  const [role, setRole] = useState('student,staff');
  const [page, setPage] = useState(1);

  const fetcher = useCallback(() => api.students(role, page), [role, page]);
  const { data, error, loading } = usePolling(fetcher, 120000);

  return (
    <section>
      <div className="page-head">
        <h2>Students &amp; Staff</h2>
        <select className="filter" value={role} onChange={(event) => { setRole(event.target.value); setPage(1); }}>
          <option value="student,staff">Students and staff</option>
          <option value="student">Students only</option>
          <option value="staff">Staff only</option>
        </select>
      </div>

      <p className="muted small">
        Responders see their own school only; the scope is applied server-side, not here.
      </p>

      <ErrorBanner error={error} />
      {loading && data === null && <p className="muted">Loading roster…</p>}

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>School</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {data?.data.map((person) => (
              <tr key={person.id}>
                <td>{person.name}</td>
                <td>{person.email}</td>
                <td>{person.role}</td>
                <td>{person.school_id}</td>
                <td>{person.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="row pager">
        <button className="btn subtle" disabled={page <= 1} onClick={() => setPage((value) => value - 1)}>
          Previous
        </button>
        <span className="muted">
          Page {data?.currentPage ?? page} of {data?.lastPage ?? '?'} · {data?.total ?? 0} people
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
