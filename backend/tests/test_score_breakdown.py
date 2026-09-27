from cryptotrace import build_trace_response, trace_wallet


def test_score_breakdowns_match_final_scores():
    outcome = trace_wallet("0x1234567890123456789012345678901234567890", max_hops=2)
    response = build_trace_response(outcome, 2)

    confidence = response.summary.confidence_breakdown
    risk = response.summary.risk_breakdown

    assert confidence is not None
    assert risk is not None
    assert confidence.final_score == response.summary.confidence_score
    assert risk.final_score == response.summary.risk_score
    assert confidence.score_type == "confidence"
    assert risk.score_type == "risk"
    assert confidence.factors
    assert risk.factors


def test_existing_score_values_are_preserved():
    outcome = trace_wallet("0x1234567890123456789012345678901234567890", max_hops=2)
    response = build_trace_response(outcome, 2)

    # Step 3 exposes the existing heuristic arithmetic; it must not silently
    # change the score itself.
    assert response.summary.confidence_score == response.summary.confidence_breakdown.final_score
    assert response.summary.risk_score == response.summary.risk_breakdown.final_score
