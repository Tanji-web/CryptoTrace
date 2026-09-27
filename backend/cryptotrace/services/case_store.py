"""Small in-memory case snapshot store used for evidence exports."""
from __future__ import annotations

from collections import OrderedDict
from threading import Lock
from typing import Optional

from cryptotrace.models import TraceResponse

MAX_CASE_SNAPSHOTS = 100

_cases: OrderedDict[str, TraceResponse] = OrderedDict()
_lock = Lock()


def save_case(response: TraceResponse) -> TraceResponse:
    """Store the exact trace response used by the UI for later export."""
    with _lock:
        _cases[response.case.case_id] = response
        _cases.move_to_end(response.case.case_id)
        while len(_cases) > MAX_CASE_SNAPSHOTS:
            _cases.popitem(last=False)
    return response


def get_case(
    case_id: str,
    *,
    target_wallet: Optional[str] = None,
    max_hops: Optional[int] = None,
) -> Optional[TraceResponse]:
    """Return a stored snapshot when it matches the requested case context."""
    with _lock:
        response = _cases.get(case_id)
        if response is None:
            return None
        if target_wallet is not None and response.summary.target_wallet != target_wallet:
            return None
        if max_hops is not None and response.summary.requested_hops != max_hops:
            return None
        _cases.move_to_end(case_id)
        return response
