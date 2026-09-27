from cryptotrace import build_trace_response, trace_wallet
from cryptotrace.registry import lookup_vasp


def test_demo_registry_has_provenance_fields():
    record = lookup_vasp("0x503209a779226e6392913734c7601313380f7192")
    assert record is not None
    assert record["verification_status"] == "demo"
    assert record["source_type"] == "public_explorer"
    assert record["source_url"].startswith("https://etherscan.io/address/")


def test_trace_response_exposes_vasp_provenance():
    outcome = trace_wallet("0x1234567890123456789012345678901234567890", max_hops=2)
    response = build_trace_response(outcome, 2)
    assert response.summary.nearest_vasp is not None
    assert response.summary.vasp_provenance is not None
    assert response.summary.vasp_provenance.verification_status == "demo"
    assert response.summary.vasp_provenance.source_url
