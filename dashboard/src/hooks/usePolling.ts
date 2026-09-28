import { useCallback, useEffect, useRef, useState } from 'react';

const DEFAULT_INTERVAL = Number(import.meta.env.VITE_POLL_INTERVAL_MS ?? 10000);

/**
 * docs/ARCHITECTURE.md §8: push notifications REQUIRE EXTERNAL SERVICE, so
 * Phase 4 ships polling as the working default. Polling pauses while the tab
 * is hidden and resumes (with an immediate refresh) when it becomes visible.
 */
export function usePolling<T>(
  fetcher: () => Promise<T>,
  intervalMs: number = DEFAULT_INTERVAL,
): { data: T | null; error: Error | null; loading: boolean; refresh: () => Promise<void> } {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(true);
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;

  const refresh = useCallback(async () => {
    try {
      setData(await fetcherRef.current());
      setError(null);
    } catch (e) {
      setError(e as Error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    let timer: number | undefined;

    const tick = async () => {
      if (document.visibilityState === 'visible') {
        await refresh();
      }
      if (!cancelled) {
        timer = window.setTimeout(tick, intervalMs);
      }
    };

    void tick();

    const onVisible = () => {
      if (document.visibilityState === 'visible') void refresh();
    };
    document.addEventListener('visibilitychange', onVisible);

    return () => {
      cancelled = true;
      if (timer !== undefined) window.clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [intervalMs, refresh]);

  return { data, error, loading, refresh };
}
