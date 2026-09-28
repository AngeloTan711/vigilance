import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import ErrorBanner from '../components/ErrorBanner';

export default function LoginPage({ roleRefusal = false }: { roleRefusal?: boolean }) {
  const { login, logout } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);

  if (roleRefusal) {
    return (
      <div className="centered">
        <div className="card login">
          <h1>VIGILANCE</h1>
          <p>
            This account is not a responder or administrator. The dashboard is restricted to those
            roles by the approved permission matrix; student and staff accounts use the mobile app.
          </p>
          <button className="btn primary" onClick={() => void logout()}>
            Sign in as someone else
          </button>
        </div>
      </div>
    );
  }

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email, password);
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="centered">
      <form className="card login" onSubmit={(event) => void submit(event)}>
        <h1>VIGILANCE</h1>
        <p className="muted">Responder &amp; administrator sign-in</p>
        <ErrorBanner error={error} />
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          autoComplete="username"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
        />
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
        />
        <button className="btn primary wide" type="submit" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
