import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import ActiveAlertsPage from './pages/ActiveAlertsPage';
import AlertDetailPage from './pages/AlertDetailPage';
import IncidentHistoryPage from './pages/IncidentHistoryPage';
import RosterPage from './pages/RosterPage';
import RespondersPage from './pages/RespondersPage';

export default function App() {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="centered muted">Loading…</div>;
  }

  if (user === null) {
    return (
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  // Responder/admin only: the approved permission matrix (§6) gives no
  // student/staff account any dashboard capability, so those accounts are
  // shown an explicit refusal rather than an empty dashboard.
  if (user.role !== 'responder' && user.role !== 'admin') {
    return <LoginPage roleRefusal />;
  }

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<ActiveAlertsPage />} />
        <Route path="/alerts/:id" element={<AlertDetailPage />} />
        <Route path="/history" element={<IncidentHistoryPage />} />
        <Route path="/roster" element={<RosterPage />} />
        {user.role === 'admin' && <Route path="/responders" element={<RespondersPage />} />}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
