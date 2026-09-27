import logging

from cryptotrace import build_trace_response
from cryptotrace.config import MAX_CANDIDATES_PER_WALLET
from cryptotrace.graph import tracer as tracer_module
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.ingestion.etherscan import finalize_candidates
from cryptotrace.models import FetchResult, TransactionCandidate


def _token_candidate(source: str, target: str) -> TransactionCandidate:
    from datetime import datetime, timezone
    return TransactionCandidate(
        from_address=source,
        to_address=target,
        asset_type="erc20",
        asset_symbol="USDC",
        amount=125.0,
        tx_hash="0x" + "a" * 64,
        timestamp=datetime(2026, 9, 27, tzinfo=timezone.utc),
        block_number=123,
        token_contract="0x" + "b" * 40,
        token_decimals=6,
        token_raw_amount="125000000",
        transaction_type="erc20",
    )


def test_erc20_transfers_are_structurally_eligible_without_eth_pricing():
    src = "0x1111111111111111111111111111111111111111"
    dst = "0x2222222222222222222222222222222222222222"
    result = finalize_candidates([_token_candidate(src, dst)])

    assert result.transactions
    assert result.transactions[0].eligible is True
    assert result.transactions[0].filter_reason == "included_unpriced_token"
    assert result.unpriced_token == 1
    assert result.filtered_below_threshold == 0
    assert result.candidate_limit == 0


def test_live_failure_penalty_path_is_reachable(monkeypatch):
    target = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    vasp = "0x503209a779226e6392913734c7601313380f7192"

    from datetime import datetime, timezone
    tx = TransactionCandidate(
        from_address=target,
        to_address=vasp,
        asset_type="native_eth",
        asset_symbol="ETH",
        amount=1.0,
        tx_hash="0x" + "c" * 64,
        timestamp=datetime(2026, 9, 27, tzinfo=timezone.utc),
        block_number=456,
        transaction_type="native_eth",
        eligible=True,
        filter_reason="included",
    )

    def fake_fetch(address, api_calls):
        if address == target:
            return FetchResult(transactions=[tx], source="live", examined=1)
        return FetchResult(
            transactions=[],
            source="live",
            error="synthetic downstream failure",
            examined=0,
            partial_data=True,
            api_warnings=["downstream source unavailable"],
        )

    monkeypatch.setattr(tracer_module, "fetch_live_for_address", fake_fetch)
    monkeypatch.setattr(tracer_module, "MAX_LIVE_API_CALLS", 30)

    outcome = trace_wallet(target, max_hops=2)
    response = build_trace_response(outcome, 2)

    assert outcome.data_source == "live_api_error"
    assert outcome.depth_stop_reason == "api_error"
    assert response.summary.nearest_vasp is not None
    assert any(f.key == "live_api_error" and f.points == -20 for f in response.summary.confidence_breakdown.factors)


def test_analysis_reports_configured_candidate_limit(monkeypatch):
    monkeypatch.setattr(tracer_module, "MAX_CANDIDATES_PER_WALLET", 7)
    target = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

    outcome = trace_wallet(target, max_hops=1)

    assert outcome.analysis["limits"]["max_candidates_per_wallet"] == 7


def test_erc20_transfer_participates_in_graph_without_eth_pricing(monkeypatch):
    target = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    vasp = "0x503209a779226e6392913734c7601313380f7192"
    token_tx = _token_candidate(target, vasp)

    def fake_fetch(address, api_calls):
        if address == target:
            return finalize_candidates([token_tx])
        return FetchResult(transactions=[], source="live", examined=0)

    monkeypatch.setattr(tracer_module, "fetch_live_for_address", fake_fetch)

    outcome = trace_wallet(target, max_hops=1)

    assert outcome.vasp_address == vasp
    assert outcome.path == [target, vasp]
    assert any(data.get("asset_type") == "erc20" for _, _, data in outcome.graph.edges(data=True))
    assert outcome.analysis["transactions_included"] == 1
    assert outcome.analysis["transactions_filtered"] == 0
    assert outcome.analysis["unpriced_token_transactions"] == 1
