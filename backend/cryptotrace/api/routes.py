"""FastAPI route handlers."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from cryptotrace.config import ETHERSCAN_API_KEY, MAX_HOPS_ALLOWED
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.models import HealthResponse, TraceRequest, TraceResponse
from cryptotrace.reporting.pdf import generate_pdf_report
from cryptotrace.services.response import build_trace_response
from cryptotrace.utils import is_valid_eth_address

router = APIRouter()


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
        return build_trace_response(trace_wallet(request.wallet_address, request.max_hops), request.max_hops)
    except Exception:
        raise HTTPException(status_code=500, detail="Internal error while tracing wallet. Please try again.")


@router.get("/api/report/{wallet}")
def report_endpoint(wallet: str, max_hops: int = 2):
    wallet = wallet.strip().lower()
    if not is_valid_eth_address(wallet):
        raise HTTPException(status_code=400, detail="Invalid Ethereum wallet address.")
    if not (1 <= max_hops <= MAX_HOPS_ALLOWED):
        raise HTTPException(status_code=400, detail=f"max_hops must be between 1 and {MAX_HOPS_ALLOWED}.")
    try:
        response_data = build_trace_response(trace_wallet(wallet, max_hops), max_hops)
        pdf_bytes = generate_pdf_report(response_data)
    except Exception:
        raise HTTPException(status_code=500, detail="Internal error while generating the report.")
    filename = f"cryptotrace_report_{wallet[:10]}.pdf"
    return Response(content=pdf_bytes, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{filename}"'})
