import json

from cryptotrace.api.routes import case_endpoint, report_endpoint, trace_endpoint
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.models import TraceRequest
from cryptotrace.services.case_store import save_case
from cryptotrace.services.response import build_trace_response
from cryptotrace.utils import generate_case_id, is_valid_case_id

TARGET = "0x1111111111111111111111111111111111111111"


def _store_case(case_id: str, max_hops: int = 2):
    response = build_trace_response(trace_wallet(TARGET, max_hops), max_hops, case_id=case_id)
    return save_case(response)


def test_case_metadata_and_id_are_present():
    case_id = generate_case_id()
    assert is_valid_case_id(case_id)
    response = build_trace_response(trace_wallet(TARGET, 2), 2, case_id=case_id)
    assert response.case.case_id == case_id
    assert response.case.schema_version == "1.0"
    assert response.case.created_at


def test_case_json_contains_case_and_trace_data():
    case_id = generate_case_id()
    _store_case(case_id, 2)
    result = case_endpoint(TARGET, 2, case_id=case_id)
    assert result.media_type == "application/json"
    payload = json.loads(result.body.decode("utf-8"))
    assert payload["case"]["case_id"] == case_id
    assert "nodes" in payload and "edges" in payload and "summary" in payload
    assert "patterns" in payload
    assert "Content-Disposition" in result.headers


def test_pdf_uses_case_id_in_filename():
    case_id = generate_case_id()
    _store_case(case_id, 2)
    result = report_endpoint(TARGET, 2, case_id=case_id)
    assert result.media_type == "application/pdf"
    assert case_id in result.headers["Content-Disposition"]


def test_exports_reuse_exact_trace_snapshot():
    traced = trace_endpoint(TraceRequest(wallet_address=TARGET, max_hops=2))
    case_id = traced.case.case_id
    exported = case_endpoint(TARGET, 2, case_id=case_id)
    payload = json.loads(exported.body.decode("utf-8"))
    assert payload["case"]["case_id"] == case_id
    assert payload["summary"]["confidence_score"] == traced.summary.confidence_score
    assert payload["summary"]["risk_score"] == traced.summary.risk_score
    assert payload["edges"] == traced.model_dump(mode="json", by_alias=True)["edges"]
