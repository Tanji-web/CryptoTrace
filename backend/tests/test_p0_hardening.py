import logging

import pytest
from fastapi import HTTPException

from cryptotrace import build_trace_response, trace_wallet
from cryptotrace.api import routes
from cryptotrace.utils import generate_case_id

TARGET = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"


def test_mock_reaches_a_vasp_at_every_supported_depth():
    for max_hops in (1, 2, 3):
        outcome = trace_wallet(TARGET, max_hops)
        assert outcome.data_source == "mock"
        assert outcome.vasp_address is not None
        assert outcome.path
        assert len(outcome.path) - 1 == max_hops
        assert outcome.reached_hops == max_hops


def test_mock_demonstrates_all_pattern_types_across_supported_depths():
    detected = set()
    for max_hops in (1, 2, 3):
        response = build_trace_response(trace_wallet(TARGET, max_hops), max_hops)
        detected.update(pattern.key for pattern in response.patterns)

    assert detected == {
        "fan_out",
        "fan_in",
        "rapid_forwarding",
        "long_route",
        "repeated_routing",
        "near_threshold_splitting",
    }


def test_missing_case_id_returns_404_instead_of_retracing():
    missing_case_id = generate_case_id()
    with pytest.raises(HTTPException) as exc_info:
        routes.case_endpoint(TARGET, 2, case_id=missing_case_id)

    assert exc_info.value.status_code == 404
    assert "Case not found" in str(exc_info.value.detail)


def test_generic_trace_errors_are_logged(monkeypatch, caplog):
    def fail_build(*_args, **_kwargs):
        raise RuntimeError("synthetic trace failure")

    monkeypatch.setattr(routes, "_build_case_response", fail_build)

    with caplog.at_level(logging.ERROR, logger="cryptotrace"):
        with pytest.raises(HTTPException) as exc_info:
            routes.trace_endpoint(
                type("Request", (), {
                    "wallet_address": TARGET,
                    "max_hops": 2,
                })()
            )

    assert exc_info.value.status_code == 500
    assert "Trace request failed" in caplog.text
