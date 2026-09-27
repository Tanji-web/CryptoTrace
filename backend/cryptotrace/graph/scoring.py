"""Transparent heuristic confidence and risk scoring."""
from __future__ import annotations

from typing import Any, Dict, List, Tuple

import networkx as nx

from cryptotrace.registry import lookup_vasp


def _factor(key: str, label: str, points: int, explanation: str) -> Dict[str, Any]:
    return {
        "key": key,
        "label": label,
        "points": int(points),
        "explanation": explanation,
    }


def compute_score_details(
    graph: nx.MultiDiGraph,
    target_address: str,
    path: List[str],
    data_source: str,
) -> Tuple[int, int, List[str], Dict[str, Any], Dict[str, Any]]:
    """Return scores plus structured factor-by-factor explanations.

    The arithmetic intentionally matches the pre-Step-3 scoring rules. This
    function only makes those rules explicit for the API, UI, and PDF report.
    """
    notes: List[str] = []

    if not path or len(path) < 2:
        notes.append("No known VASP reachable within the requested hop depth.")
        confidence_breakdown = {
            "score_type": "confidence",
            "base_score": 0,
            "factors": [
                _factor(
                    "no_reachable_vasp",
                    "No reachable VASP",
                    0,
                    "No known VASP was reachable within the requested hop depth.",
                )
            ],
            "final_score": 0,
        }
        risk_breakdown = {
            "score_type": "risk",
            "base_score": 10,
            "factors": [
                _factor(
                    "no_reachable_vasp",
                    "No reachable VASP",
                    0,
                    "Fallback heuristic risk used because no known VASP path was found.",
                )
            ],
            "final_score": 10,
        }
        return 0, 10, notes, confidence_breakdown, risk_breakdown

    hop_count = len(path) - 1
    confidence_base = {1: 90, 2: 65, 3: 40}.get(hop_count, 20)
    confidence = confidence_base
    confidence_factors: List[Dict[str, Any]] = []
    confidence_factors.append(
        _factor(
            "hop_distance",
            f"{hop_count}-hop path",
            0,
            f"Base heuristic confidence for an actual {hop_count}-hop path is {confidence_base}.",
        )
    )
    notes.append(f"Base heuristic confidence from actual hop distance ({hop_count}): {confidence_base}.")

    direct_edge = graph.has_edge(target_address, path[-1]) or graph.has_edge(path[-1], target_address)
    if direct_edge:
        confidence = min(100, confidence + 5)
        confidence_factors.append(
            _factor("direct_edge", "Direct target ↔ VASP edge (1-hop)", 5, "Because the selected path is exactly 1 hop, a direct target↔VASP edge necessarily exists; this +5 is not independent evidence.")
        )
        notes.append("Direct transaction edge exists between target and VASP: +5.")
    else:
        confidence_factors.append(
            _factor("direct_edge", "Direct target ↔ VASP edge (1-hop)", 0, "A direct edge is only expected for a 1-hop attribution path; longer paths do not receive this factor.")
        )

    intermediary_count = max(0, len(path) - 2)
    intermediary_penalty = intermediary_count * 8
    confidence = max(0, confidence - intermediary_penalty)
    if intermediary_count:
        confidence_factors.append(
            _factor(
                "intermediaries",
                f"{intermediary_count} intermediary wallet(s)",
                -intermediary_penalty,
                f"Each intermediary wallet reduces confidence by 8 points ({intermediary_penalty} total).",
            )
        )
        notes.append(f"{intermediary_count} intermediary wallet(s) reduce confidence by {intermediary_penalty}.")
    else:
        confidence_factors.append(
            _factor("intermediaries", "Intermediary wallets", 0, "No intermediary wallet lies between the target and VASP on the selected path.")
        )

    vasp = lookup_vasp(path[-1])
    if vasp and vasp.get("verification_status") == "verified":
        confidence = min(100, confidence + 10)
        confidence_factors.append(
            _factor("verified_registry", "Verified VASP registry record", 10, "The matched registry record is explicitly marked verified.")
        )
        notes.append("VASP registry record has verification_status=verified: +10.")
    else:
        status = vasp.get("verification_status", "unknown") if vasp else "unknown"
        confidence_factors.append(
            _factor(
                "verified_registry",
                "Verified VASP registry record",
                0,
                f"Registry verification status is {status}; no verification bonus is applied.",
            )
        )
        notes.append(f"VASP registry record is not independently verified (status: {status}); no verification bonus applied.")

    if data_source.startswith("mock"):
        confidence = max(0, confidence - 15)
        confidence_factors.append(
            _factor("mock_data", "Mock/demo data", -15, "The trace is based on deterministic demonstration data.")
        )
        notes.append("Result derived from mock/demo data: -15.")
    else:
        confidence_factors.append(
            _factor("mock_data", "Mock/demo data", 0, "The trace is not marked as mock/demo data.")
        )

    if data_source == "live_api_error":
        confidence = max(0, confidence - 20)
        confidence_factors.append(
            _factor("live_api_error", "Live API error", -20, "A live API error prevented complete traversal.")
        )
        notes.append("Live API error prevented complete traversal: -20.")
    else:
        confidence_factors.append(
            _factor("live_api_error", "Live API error", 0, "No live API error penalty applies to this result.")
        )

    risk_base = 20
    risk = risk_base
    risk_factors: List[Dict[str, Any]] = [
        _factor("base_risk", "Base heuristic risk", 0, "Base heuristic risk starts at 20.")
    ]

    intermediary_risk = intermediary_count * 15
    risk += intermediary_risk
    if intermediary_count:
        risk_factors.append(
            _factor(
                "intermediaries",
                f"{intermediary_count} intermediary wallet(s)",
                intermediary_risk,
                f"Each intermediary wallet adds 15 risk points ({intermediary_risk} total).",
            )
        )
    else:
        risk_factors.append(
            _factor("intermediaries", "Intermediary wallets", 0, "No intermediary wallet penalty is present on the selected path.")
        )

    sparse_risk = 0
    if len(graph.nodes) > 0 and (sum(dict(graph.degree()).values()) / len(graph.nodes)) < 2:
        sparse_risk = 10
        risk += sparse_risk
        notes.append("Sparse graph connectivity contributes to heuristic risk: +10.")
        risk_factors.append(
            _factor("sparse_graph", "Sparse graph connectivity", 10, "Average graph degree is below 2, indicating sparse connectivity.")
        )
    else:
        risk_factors.append(
            _factor("sparse_graph", "Sparse graph connectivity", 0, "The traced graph does not meet the sparse-connectivity heuristic.")
        )

    fragmented_risk = 0
    if len(graph.edges) >= 8 and len({d.get("tx_hash") for _, _, d in graph.edges(data=True)}) >= 8:
        fragmented_risk = 5
        risk += fragmented_risk
        notes.append("Fragmented routing pattern contributes to heuristic risk: +5.")
        risk_factors.append(
            _factor("fragmented_routing", "Fragmented routing pattern", 5, "The graph contains at least 8 edges with distinct transaction hashes.")
        )
    else:
        risk_factors.append(
            _factor("fragmented_routing", "Fragmented routing pattern", 0, "The graph does not meet the fragmented-routing heuristic.")
        )

    risk = max(0, min(100, risk))
    confidence = max(0, min(100, confidence))

    confidence_breakdown = {
        "score_type": "confidence",
        "base_score": confidence_base,
        "factors": confidence_factors,
        "final_score": int(confidence),
    }
    risk_breakdown = {
        "score_type": "risk",
        "base_score": risk_base,
        "factors": risk_factors,
        "final_score": int(risk),
    }
    return int(confidence), int(risk), notes, confidence_breakdown, risk_breakdown


def compute_scores(
    graph: nx.MultiDiGraph,
    target_address: str,
    path: List[str],
    data_source: str,
) -> Tuple[int, int, List[str]]:
    """Backward-compatible score API used by existing callers."""
    confidence, risk, notes, _, _ = compute_score_details(graph, target_address, path, data_source)
    return confidence, risk, notes
