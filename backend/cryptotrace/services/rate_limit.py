"""Small in-memory per-client sliding-window rate limiter."""
from __future__ import annotations

from collections import defaultdict, deque
from threading import Lock
from time import monotonic


class InMemoryRateLimiter:
    def __init__(self, limit: int, window_seconds: int) -> None:
        self.limit = max(1, int(limit))
        self.window_seconds = max(1, int(window_seconds))
        self._lock = Lock()
        self._events: dict[str, deque[float]] = defaultdict(deque)

    def allow(self, key: str) -> tuple[bool, int]:
        now = monotonic()
        cutoff = now - self.window_seconds
        with self._lock:
            events = self._events[key]
            while events and events[0] <= cutoff:
                events.popleft()
            if len(events) >= self.limit:
                retry_after = max(1, int(events[0] + self.window_seconds - now + 0.999))
                return False, retry_after
            events.append(now)
            return True, 0

    def reset(self) -> None:
        with self._lock:
            self._events.clear()
