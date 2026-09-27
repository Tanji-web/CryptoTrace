"""Translate internal graph outcomes into public API responses."""
from __future__ import annotations

from datetime import datetime, timezone

from cryptotrace.graph.patterns import detect_pattern_indicators
from cryptotrace.graph.scoring import compute_score_details
from cryptotrace.models import (
    AnalysisModel,
    AttributionSummary,
    CaseMetadataModel,
    EdgeModel,
    NodeModel,
    PatternIndicatorModel,
    ScoreBreakdownModel,
    TraceOutcome,
    TraceResponse,
    VaspProvenanceModel,
    PathHopModel,
)
from cryptotrace.registry import lookup_vasp
from cryptotrace.utils import generate_case_id, transaction_explorer_url


def build_trace_response(
    outcome: TraceOutcome,
    max_hops: int,
    *,
    case_id: str | None = None,
    created_at: str | None = None,
) -> TraceResponse:
    case = CaseMetadataModel(
        case_id=case_id or generate_case_id(),
        created_at=created_at or datetime.now(timezone.utc).isoformat(),
    )

    nodes = [NodeModel(
        id=node_id,
        label="VASP" if data.get("is_vasp") else ("Target Wallet" if data.get("is_target") else "Wallet"),
        is_vasp=bool(data.get("is_vasp")),
        vasp_verified=bool(data.get("vasp_verified", False)),
        vasp_name=data.get("vasp_name"),
        vasp_type=data.get("vasp_type"),
        is_target=bool(data.get("is_target")),
    ) for node_id, data in outcome.graph.nodes(data=True)]

    edges = [
        EdgeModel(
            **{
                "from": u,
                "to": v,
                **{
                    k: data.get(k)
                    for k in [
                        "asset_type",
                        "asset_symbol",
                        "amount",
                        "tx_hash",
                        "timestamp",
                        "block_number",
                        "transaction_type",
                        "token_contract",
                        "token_decimals",
                        "token_raw_amount",
                    ]
                },
            },
            explorer_url=transaction_explorer_url(data.get("tx_hash", ""), outcome.data_source),
        )
        for u, v, data in outcome.graph.edges(data=True)
    ]

    confidence, risk, notes, confidence_breakdown_raw, risk_breakdown_raw = compute_score_details(
        outcome.graph, outcome.target_address, outcome.path, outcome.data_source
    )
    vasp_meta = lookup_vasp(outcome.vasp_address) if outcome.vasp_address else None
    confidence_breakdown = ScoreBreakdownModel(**confidence_breakdown_raw)
    risk_breakdown = ScoreBreakdownModel(**risk_breakdown_raw)
    vasp_provenance = None
    if vasp_meta:
        vasp_provenance = VaspProvenanceModel(
            source=vasp_meta.get("source", "unknown"),
            source_type=vasp_meta.get("source_type", "unknown"),
            source_url=vasp_meta.get("source_url") or None,
            verification_status=vasp_meta.get("verification_status", "unknown"),
            last_verified=vasp_meta.get("last_verified") or None,
            notes=vasp_meta.get("notes") or None,
        )

    pattern_indicators = [
        PatternIndicatorModel(**item)
        for item in detect_pattern_indicators(
            outcome.graph, outcome.path, outcome.transactions_by_node
        )
    ]

    summary = AttributionSummary(
        target_wallet=outcome.target_address,
        nearest_vasp=vasp_meta["name"] if vasp_meta else None,
        vasp_type=vasp_meta["type"] if vasp_meta else None,
        vasp_provenance=vasp_provenance,
        hop_count=(len(outcome.path) - 1) if outcome.path else None,
        requested_hops=max_hops,
        reached_hops=outcome.reached_hops,
        depth_stop_reason=outcome.depth_stop_reason,
        confidence_score=confidence,
        risk_score=risk,
        data_source=outcome.data_source,
        path=outcome.path,
        vasp_direction=outcome.vasp_direction,
        path_hops=[
            PathHopModel(
                **{
                    "from": hop.from_address,
                    "to": hop.to_address,
                    "direction": hop.direction,
                    "outgoing_tx_hashes": hop.outgoing_tx_hashes,
                    "incoming_tx_hashes": hop.incoming_tx_hashes,
                }
            )
            for hop in outcome.path_hops
        ],
        scoring_notes=notes,
        confidence_breakdown=confidence_breakdown,
        risk_breakdown=risk_breakdown,
    )
    return TraceResponse(
        case=case,
        nodes=nodes,
        edges=edges,
        summary=summary,
        analysis=AnalysisModel(**outcome.analysis),
        patterns=pattern_indicators,
    )
