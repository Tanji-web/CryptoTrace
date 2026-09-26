"""Translate internal graph outcomes into public API responses."""
from __future__ import annotations

from cryptotrace.graph.scoring import compute_scores
from cryptotrace.models import AnalysisModel, AttributionSummary, EdgeModel, NodeModel, TraceOutcome, TraceResponse
from cryptotrace.registry import lookup_vasp


def build_trace_response(outcome: TraceOutcome, max_hops: int) -> TraceResponse:
    nodes = [NodeModel(
        id=node_id,
        label="VASP" if data.get("is_vasp") else ("Target Wallet" if data.get("is_target") else "Wallet"),
        is_vasp=bool(data.get("is_vasp")),
        vasp_name=data.get("vasp_name"),
        vasp_type=data.get("vasp_type"),
        is_target=bool(data.get("is_target")),
    ) for node_id, data in outcome.graph.nodes(data=True)]

    edges = [EdgeModel(
        **{"from": u, "to": v, **{k: data.get(k) for k in [
            "asset_type", "asset_symbol", "amount", "tx_hash", "timestamp", "block_number", "transaction_type", "token_contract",
            "token_decimals", "token_raw_amount"]}}
    ) for u, v, data in outcome.graph.edges(data=True)]

    confidence, risk, notes = compute_scores(outcome.graph, outcome.target_address, outcome.path, outcome.data_source)
    vasp_meta = lookup_vasp(outcome.vasp_address) if outcome.vasp_address else None
    summary = AttributionSummary(
        target_wallet=outcome.target_address,
        nearest_vasp=vasp_meta["name"] if vasp_meta else None,
        vasp_type=vasp_meta["type"] if vasp_meta else None,
        hop_count=(len(outcome.path) - 1) if outcome.path else None,
        requested_hops=max_hops,
        reached_hops=outcome.reached_hops,
        depth_stop_reason=outcome.depth_stop_reason,
        confidence_score=confidence,
        risk_score=risk,
        data_source=outcome.data_source,
        path=outcome.path,
        scoring_notes=notes,
    )
    return TraceResponse(nodes=nodes, edges=edges, summary=summary, analysis=AnalysisModel(**outcome.analysis))
