import type { ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function Layout({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth();

  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand">
          VIGILANCE<span className="brand-sub">Responder Dashboard</span>
        </div>
        <nav className="nav">
          <NavLink to="/" end>
            Active Alerts
          </NavLink>
          <NavLink to="/history">Incident History</NavLink>
          <NavLink to="/roster">Students &amp; Staff</NavLink>
          {user?.role === 'admin' && <NavLink to="/responders">Responders</NavLink>}
        </nav>
        <div className="session">
          <span className="who">
            {user?.name} <span className="role-chip">{user?.role}</span>
          </span>
          <button className="btn subtle" onClick={() => void logout()}>
            Sign out
          </button>
        </div>
      </header>
      <main className="content">{children}</main>
    </div>
  );
}
