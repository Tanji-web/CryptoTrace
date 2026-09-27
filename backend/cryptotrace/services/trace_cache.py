"""Short-TTL cache for repeated trace computations."""
from __future__ import annotations

from dataclasses import dataclass
from threading import Lock
from time import monotonic
from typing import Optional

from cryptotrace.config import TRACE_CACHE_TTL_SECONDS
from cryptotrace.models import TraceOutcome


@dataclass
class _CacheEntry:
    expires_at: float
    outcome: TraceOutcome


_lock = Lock()
_cache: dict[tuple[str, int, str], _CacheEntry] = {}


def _key(wallet: str, max_hops: int, mode: str) -> tuple[str, int, str]:
    return wallet.lower(), int(max_hops), mode


def get_cached_trace(wallet: str, max_hops: int, mode: str) -> Optional[TraceOutcome]:
    if TRACE_CACHE_TTL_SECONDS <= 0:
        return None
    key = _key(wallet, max_hops, mode)
    now = monotonic()
    with _lock:
        entry = _cache.get(key)
        if entry is None:
            return None
        if entry.expires_at <= now:
            _cache.pop(key, None)
            return None
        return entry.outcome


def put_cached_trace(wallet: str, max_hops: int, mode: str, outcome: TraceOutcome) -> None:
    if TRACE_CACHE_TTL_SECONDS <= 0:
        return
    key = _key(wallet, max_hops, mode)
    with _lock:
        _cache[key] = _CacheEntry(
            expires_at=monotonic() + TRACE_CACHE_TTL_SECONDS,
            outcome=outcome,
        )


def clear_trace_cache() -> None:
    with _lock:
        _cache.clear()
