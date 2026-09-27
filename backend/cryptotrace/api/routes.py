"""FastAPI route handlers."""
from __future__ import annotations

import json
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from cryptotrace.config import ETHERSCAN_API_KEY, MAX_HOPS_ALLOWED, logger
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.models import HealthResponse, TraceRequest, TraceResponse
from cryptotrace.reporting.pdf import generate_pdf_report
from cryptotrace.services.case_store import get_case, save_case
from cryptotrace.services.trace_cache import get_cached_trace, put_cached_trace
from cryptotrace.services.response import build_trace_response
from cryptotrace.utils import is_valid_case_id, is_valid_eth_address

router = APIRouter()


def _build_case_response(wallet: str, max_hops: int, case_id: str | None) -> TraceResponse:
    """Return an existing case snapshot or create a new case when no ID was supplied.

    A supplied case ID is a reference to an existing evidence snapshot. It must
    never silently trigger a fresh trace if the snapshot is missing or expired.
    """
    if case_id:
        existing = get_case(case_id, target_wallet=wallet, max_hops=max_hops)
        if existing is None:
            raise HTTPException(
                status_code=404,
                detail="Case not found, expired, or does not match the requested wallet and hop depth.",
            )
        return existing

    mode = "live" if ETHERSCAN_API_KEY else "mock"
    outcome = get_cached_trace(wallet, max_hops, mode)
    if outcome is None:
        outcome = trace_wallet(wallet, max_hops)
        if outcome.data_source != "live_api_error" and not outcome.analysis.get("partial_data", False):
            put_cached_trace(wallet, max_hops, mode, outcome)
    response = build_trace_response(outcome, max_hops)
    return save_case(response)


@router.get("/api/health", response_model=HealthResponse)
def health_check() -> HealthResponse:
    return HealthResponse(
        status="online",
        etherscan_key_configured=bool(ETHERSCAN_API_KEY),
        timestamp=datetime.now(timezone.utc).isoformat(),
    )


@router.post("/api/trace", response_model=TraceResponse)
def trace_endpoint(request: TraceRequest) -> TraceResponse:
    try:
        return _build_case_response(request.wallet_address, request.max_hops, None)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Trace request failed for wallet=%s", request.wallet_address)
        raise HTTPException(status_code=500, detail="Internal error while tracing wallet. Please try again.")


@router.get("/api/report/{wallet}")
def report_endpoint(wallet: str, max_hops: int = 2, case_id: str | None = None):
    wallet = wallet.strip().lower()
    if not is_valid_eth_address(wallet):
        raise HTTPException(status_code=400, detail="Invalid Ethereum wallet address.")
    if not (1 <= max_hops <= MAX_HOPS_ALLOWED):
        raise HTTPException(status_code=400, detail=f"max_hops must be between 1 and {MAX_HOPS_ALLOWED}.")
    if case_id is not None and not is_valid_case_id(case_id):
        raise HTTPException(status_code=400, detail="Invalid case_id format.")
    try:
        response_data = _build_case_response(wallet, max_hops, case_id)
        pdf_bytes = generate_pdf_report(response_data)
    except HTTPException:
        raise
    except Exception:
        logger.exception(
            "Evidence PDF generation failed for wallet=%s case_id=%s max_hops=%s",
            wallet,
            case_id,
            max_hops,
        )
        raise HTTPException(status_code=500, detail="Internal error while generating the report.")
    filename = f"cryptotrace_report_{response_data.case.case_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/api/case/{wallet}")
def case_endpoint(wallet: str, max_hops: int = 2, case_id: str | None = None):
    wallet = wallet.strip().lower()
    if not is_valid_eth_address(wallet):
        raise HTTPException(status_code=400, detail="Invalid Ethereum wallet address.")
    if not (1 <= max_hops <= MAX_HOPS_ALLOWED):
        raise HTTPException(status_code=400, detail=f"max_hops must be between 1 and {MAX_HOPS_ALLOWED}.")
    if case_id is not None and not is_valid_case_id(case_id):
        raise HTTPException(status_code=400, detail="Invalid case_id format.")
    try:
        response_data = _build_case_response(wallet, max_hops, case_id)
        payload = json.dumps(response_data.model_dump(mode="json", by_alias=True), indent=2, sort_keys=True)
    except HTTPException:
        raise
    except Exception:
        logger.exception(
            "Case JSON export failed for wallet=%s case_id=%s max_hops=%s",
            wallet,
            case_id,
            max_hops,
        )
        raise HTTPException(status_code=500, detail="Internal error while exporting the case JSON.")
    filename = f"cryptotrace_case_{response_data.case.case_id}.json"
    return Response(
        content=payload,
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
