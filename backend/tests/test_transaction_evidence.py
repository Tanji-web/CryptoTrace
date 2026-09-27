from cryptotrace import build_trace_response, trace_wallet
from cryptotrace.utils import transaction_explorer_url


def test_live_transaction_hash_gets_explorer_url():
    tx_hash = "0x" + "a" * 64
    assert transaction_explorer_url(tx_hash, "live") == f"https://etherscan.io/tx/{tx_hash}"


def test_mock_transaction_hash_has_no_explorer_url():
    tx_hash = "0x" + "a" * 64
    assert transaction_explorer_url(tx_hash, "mock") is None


def test_trace_response_exposes_transaction_evidence_fields():
    outcome = trace_wallet("0x1234567890123456789012345678901234567890", max_hops=2)
    response = build_trace_response(outcome, 2)
    assert response.edges
    edge = response.edges[0]
    assert edge.tx_hash
    assert edge.timestamp
    assert edge.transaction_type
    assert edge.explorer_url is None  # deterministic mock data has no real explorer record
