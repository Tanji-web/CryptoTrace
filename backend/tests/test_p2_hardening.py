import json

from fastapi.testclient import TestClient

from cryptotrace.api.app import create_app
from cryptotrace.graph.scoring import compute_score_details
from cryptotrace.ingestion.mock import transactions_for_mock_address
from cryptotrace.models import TraceRequest
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.registry import KNOWN_VASP_WALLETS
from cryptotrace.services.rate_limit import InMemoryRateLimiter
from cryptotrace.services.trace_cache import clear_trace_cache, get_cached_trace, put_cached_trace


def test_direct_edge_explanation_is_not_presented_as_independent_evidence():
    target = "0x1111111111111111111111111111111111111111"
    outcome = trace_wallet(target, 1)
    assert outcome.path and len(outcome.path) == 2
    confidence, _, _, breakdown, _ = compute_score_details(
        outcome.graph, target, outcome.path, outcome.data_source
    )
    direct = next(f for f in breakdown["factors"] if f["key"] == "direct_edge")
    assert direct["points"] == 5
    assert "not independent evidence" in direct["explanation"]
    assert confidence == breakdown["final_score"]


def test_vasp_verification_state_is_surfaceable():
    target = "0x1111111111111111111111111111111111111111"
    outcome = trace_wallet(target, 1)
    response_nodes = {node: data for node, data in outcome.graph.nodes(data=True)}
    vasp = outcome.vasp_address
    assert vasp in KNOWN_VASP_WALLETS
    assert response_nodes[vasp]["vasp_verified"] is False


def test_rate_limiter_blocks_after_limit_and_reports_retry():
    limiter = InMemoryRateLimiter(2, 60)
    assert limiter.allow("127.0.0.1")[0] is True
    assert limiter.allow("127.0.0.1")[0] is True
    allowed, retry = limiter.allow("127.0.0.1")
    assert allowed is False
    assert retry >= 1


def test_asgi_health_and_trace_endpoints_work():
    client = TestClient(create_app())
    health = client.get("/api/health")
    assert health.status_code == 200
    assert health.json()["status"] == "online"

    trace = client.post(
        "/api/trace",
        json={"wallet_address": "0x1111111111111111111111111111111111111111", "max_hops": 2},
    )
    assert trace.status_code == 200
    payload = trace.json()
    assert payload["case"]["case_id"].startswith("CT-")
    assert "summary" in payload and "edges" in payload and "patterns" in payload

    invalid = client.post("/api/trace", json={"wallet_address": "not-an-address", "max_hops": 2})
    assert invalid.status_code == 422


def test_trace_cache_service_is_not_used_for_live_api_error(monkeypatch):
    # Structural regression check: the API route is expected to cache only
    # complete outcomes, leaving degraded live results uncached.
    from cryptotrace.api import routes
    from cryptotrace.models import TraceOutcome

    captured = []

    def fake_get(*_args, **_kwargs):
        return None

    def fake_put(*args, **kwargs):
        captured.append((args, kwargs))

    class DummyOutcome:
        data_source = "live_api_error"
        analysis = {"partial_data": False}

    monkeypatch.setattr(routes, "get_cached_trace", fake_get)
    monkeypatch.setattr(routes, "trace_wallet", lambda *_args, **_kwargs: DummyOutcome())
    monkeypatch.setattr(routes, "build_trace_response", lambda outcome, max_hops: type("R", (), {"case": type("C", (), {"case_id": "CT-20260101000000-ABCDEF"})()})())
    monkeypatch.setattr(routes, "save_case", lambda response: response)
    monkeypatch.setattr(routes, "put_cached_trace", fake_put)
    routes._build_case_response("0x1111111111111111111111111111111111111111", 1, None)
    assert captured == []


def test_trace_cache_round_trip():
    clear_trace_cache()
    target = "0x1111111111111111111111111111111111111111"
    outcome = trace_wallet(target, 1)
    put_cached_trace(target, 1, "mock", outcome)
    assert get_cached_trace(target, 1, "mock") is outcome
    assert get_cached_trace(target, 2, "mock") is None
    clear_trace_cache()
