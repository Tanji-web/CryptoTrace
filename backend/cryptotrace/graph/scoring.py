"""Transparent heuristic confidence and risk scoring."""
from __future__ import annotations

from typing import List, Tuple

import networkx as nx

from cryptotrace.registry import lookup_vasp


def compute_scores(graph: nx.MultiDiGraph, target_address: str, path: List[str], data_source: str) -> Tuple[int, int, List[str]]:
    notes: List[str] = []
    if not path or len(path) < 2:
        notes.append("No known VASP reachable within the requested hop depth.")
        return 0, 10, notes
    hop_count = len(path) - 1
    confidence = {1: 90, 2: 65, 3: 40}.get(hop_count, 20)
    notes.append(f"Base heuristic confidence from actual hop distance ({hop_count}): {confidence}.")
    direct_edge = graph.has_edge(target_address, path[-1]) or graph.has_edge(path[-1], target_address)
    if direct_edge:
        confidence = min(100, confidence + 5)
        notes.append("Direct transaction edge exists between target and VASP: +5.")
    intermediary_count = max(0, len(path) - 2)
    confidence = max(0, confidence - intermediary_count * 8)
    if intermediary_count:
        notes.append(f"{intermediary_count} intermediary wallet(s) reduce confidence by {intermediary_count * 8}.")
    vasp = lookup_vasp(path[-1])
    if vasp and vasp.get("verified") == "true":
        confidence = min(100, confidence + 10)
        notes.append("VASP address is marked verified: +10.")
    else:
        notes.append("VASP address is not marked verified; no verification bonus applied.")
    if data_source.startswith("mock"):
        confidence = max(0, confidence - 15)
        notes.append("Result derived from mock/demo data: -15.")
    if data_source == "live_api_error":
        confidence = max(0, confidence - 20)
        notes.append("Live API error prevented complete traversal: -20.")

    risk = 20 + intermediary_count * 15
    if len(graph.nodes) > 0 and (sum(dict(graph.degree()).values()) / len(graph.nodes)) < 2:
        risk += 10
        notes.append("Sparse graph connectivity contributes to heuristic risk: +10.")
    if len(graph.edges) >= 8 and len({d.get("tx_hash") for _, _, d in graph.edges(data=True)}) >= 8:
        risk += 5
        notes.append("Fragmented routing pattern contributes to heuristic risk: +5.")
    risk = max(0, min(100, risk))
    confidence = max(0, min(100, confidence))
    return int(confidence), int(risk), notes
