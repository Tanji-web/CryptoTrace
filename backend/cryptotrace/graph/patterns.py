"""Graph-derived investigation pattern indicators.

These indicators are descriptive heuristics. They do not establish illicit
activity, ownership, intent, or attribution on their own.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple

import networkx as nx

from cryptotrace.config import MIN_TRANSFER_ETH
from cryptotrace.models import TransactionCandidate


RAPID_FORWARD_WINDOW = timedelta(minutes=15)
NEAR_THRESHOLD_WINDOW = timedelta(minutes=60)
NEAR_THRESHOLD_MAX_MULTIPLIER = 2.0
MIN_COUNTERPARTIES = 3
MIN_REPEATED_TRANSFERS = 2
MIN_NEAR_THRESHOLD_TRANSFERS = 3


def _parse_timestamp(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _edge_hashes(edges: Iterable[Tuple[str, str, Mapping[str, Any]]], limit: int = 12) -> List[str]:
    hashes: List[str] = []
    seen: Set[str] = set()
    for _, _, data in edges:
        tx_hash = str(data.get("tx_hash") or "")
        if tx_hash and tx_hash not in seen:
            seen.add(tx_hash)
            hashes.append(tx_hash)
        if len(hashes) >= limit:
            break
    return hashes


def _pattern(
    key: str,
    label: str,
    severity: str,
    description: str,
    node_ids: Sequence[str] = (),
    tx_hashes: Sequence[str] = (),
    evidence: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    return {
        "key": key,
        "label": label,
        "severity": severity,
        "description": description,
        "node_ids": list(dict.fromkeys(node_ids)),
        "tx_hashes": list(dict.fromkeys(tx_hashes)),
        "evidence": evidence or {},
    }


def _outgoing_edges(graph: nx.MultiDiGraph, node: str):
    return [(u, v, data) for u, v, _, data in graph.out_edges(node, keys=True, data=True)]


def _incoming_edges(graph: nx.MultiDiGraph, node: str):
    return [(u, v, data) for u, v, _, data in graph.in_edges(node, keys=True, data=True)]


def _path_edge_records(graph: nx.MultiDiGraph, path: Sequence[str]):
    records = []
    for a, b in zip(path, path[1:]):
        edge_bundle = graph.get_edge_data(a, b, default={})
        if edge_bundle:
            for _, data in edge_bundle.items():
                records.append((a, b, data))
        reverse_bundle = graph.get_edge_data(b, a, default={})
        if reverse_bundle:
            for _, data in reverse_bundle.items():
                records.append((b, a, data))
    return records


def detect_pattern_indicators(
    graph: nx.MultiDiGraph,
    path: Sequence[str],
    transactions_by_node: Mapping[str, Sequence[TransactionCandidate]],
) -> List[Dict[str, Any]]:
    """Return deterministic, explainable graph-derived investigation indicators."""
    patterns: List[Dict[str, Any]] = []

    # 1) Fan-out: one wallet sends eligible value to 3+ distinct downstream wallets.
    for node in graph.nodes:
        outgoing = _outgoing_edges(graph, node)
        counterparties = {v for _, v, _ in outgoing if v != node}
        if len(counterparties) >= MIN_COUNTERPARTIES:
            patterns.append(
                _pattern(
                    "fan_out",
                    "Fan-out",
                    "attention",
                    "This wallet sends eligible transfers to multiple distinct downstream addresses in the traced graph.",
                    node_ids=[node],
                    tx_hashes=_edge_hashes(outgoing),
                    evidence={
                        "distinct_downstream_addresses": len(counterparties),
                        "transfer_count": len(outgoing),
                    },
                )
            )

    # 2) Fan-in: multiple upstream wallets send eligible value into one wallet.
    for node in graph.nodes:
        incoming = _incoming_edges(graph, node)
        counterparties = {u for u, _, _ in incoming if u != node}
        if len(counterparties) >= MIN_COUNTERPARTIES:
            patterns.append(
                _pattern(
                    "fan_in",
                    "Fan-in",
                    "attention",
                    "This wallet receives eligible transfers from multiple distinct upstream addresses in the traced graph.",
                    node_ids=[node],
                    tx_hashes=_edge_hashes(incoming),
                    evidence={
                        "distinct_upstream_addresses": len(counterparties),
                        "transfer_count": len(incoming),
                    },
                )
            )

    # 3) Rapid forwarding: value enters and leaves the same wallet within 15 minutes.
    for node in graph.nodes:
        incoming = _incoming_edges(graph, node)
        outgoing = _outgoing_edges(graph, node)
        evidence_pairs = []
        for in_u, _, in_data in incoming:
            in_ts = _parse_timestamp(in_data.get("timestamp"))
            if in_ts is None:
                continue
            for _, out_v, out_data in outgoing:
                out_ts = _parse_timestamp(out_data.get("timestamp"))
                if out_ts is None or out_ts < in_ts:
                    continue
                delta = out_ts - in_ts
                if delta <= RAPID_FORWARD_WINDOW:
                    evidence_pairs.append((in_u, out_v, in_data, out_data, delta))
        if evidence_pairs:
            tx_hashes: List[str] = []
            for _, _, in_data, out_data, _ in evidence_pairs[:6]:
                tx_hashes.extend([str(in_data.get("tx_hash") or ""), str(out_data.get("tx_hash") or "")])
            tx_hashes = [x for x in dict.fromkeys(tx_hashes) if x]
            fastest_seconds = int(min(pair[4].total_seconds() for pair in evidence_pairs))
            patterns.append(
                _pattern(
                    "rapid_forwarding",
                    "Rapid forwarding",
                    "attention",
                    "An incoming eligible transfer is followed by an outgoing eligible transfer from the same wallet within 15 minutes. This is an activity pattern, not proof of intent.",
                    node_ids=[node],
                    tx_hashes=tx_hashes,
                    evidence={
                        "window_minutes": 15,
                        "matched_sequences": len(evidence_pairs),
                        "fastest_gap_seconds": fastest_seconds,
                    },
                )
            )

    # 4) Long route: with the current max depth this primarily means a 3-hop route.
    hop_count = max(0, len(path) - 1)
    if hop_count >= 3:
        path_records = _path_edge_records(graph, path)
        patterns.append(
            _pattern(
                "long_route",
                "Long routing chain",
                "informational",
                f"The selected attribution path spans {hop_count} hops before reaching the matched VASP.",
                node_ids=list(path),
                tx_hashes=_edge_hashes(path_records),
                evidence={"hop_count": hop_count},
            )
        )

    # 5) Repeated routing: an intermediary has multiple eligible transfers on both sides.
    if len(path) >= 3:
        for node in path[1:-1]:
            incoming = _incoming_edges(graph, node)
            outgoing = _outgoing_edges(graph, node)
            distinct_in = {u for u, _, _ in incoming if u != node}
            distinct_out = {v for _, v, _ in outgoing if v != node}
            if len(incoming) >= MIN_REPEATED_TRANSFERS and len(outgoing) >= MIN_REPEATED_TRANSFERS:
                patterns.append(
                    _pattern(
                        "repeated_routing",
                        "Repeated routing through intermediary",
                        "attention",
                        "An intermediary on the selected path has multiple eligible inbound and outbound transfers within the traced graph.",
                        node_ids=[node],
                        tx_hashes=_edge_hashes(incoming + outgoing),
                        evidence={
                            "inbound_transfer_count": len(incoming),
                            "outbound_transfer_count": len(outgoing),
                            "distinct_inbound_addresses": len(distinct_in),
                            "distinct_outbound_addresses": len(distinct_out),
                        },
                    )
                )

    # 6) Near-threshold splitting indicator: 3+ outbound transfers close to the configured threshold.
    for node, transactions in transactions_by_node.items():
        near_threshold = [
            tx for tx in transactions
            if tx.eligible
            and tx.asset_type in {"native_eth", "internal_eth"}
            and MIN_TRANSFER_ETH <= tx.amount <= MIN_TRANSFER_ETH * NEAR_THRESHOLD_MAX_MULTIPLIER
            and tx.from_address == node
        ]
        near_threshold.sort(key=lambda tx: tx.timestamp)
        if len(near_threshold) < MIN_NEAR_THRESHOLD_TRANSFERS:
            continue

        for start_index in range(len(near_threshold)):
            window_start = near_threshold[start_index].timestamp
            window = [
                tx for tx in near_threshold[start_index:]
                if tx.timestamp - window_start <= NEAR_THRESHOLD_WINDOW
            ]
            if len(window) < MIN_NEAR_THRESHOLD_TRANSFERS:
                continue
            patterns.append(
                _pattern(
                    "near_threshold_splitting",
                    "Near-threshold transfer cluster",
                    "attention",
                    "Multiple outbound transfers from the same wallet sit close to the configured minimum-transfer threshold within a short window. This can be consistent with value splitting, but does not establish intent.",
                    node_ids=[node],
                    tx_hashes=[tx.tx_hash for tx in window[:12]],
                    evidence={
                        "transfer_count": len(window),
                        "threshold_eth": MIN_TRANSFER_ETH,
                        "max_transfer_eth": MIN_TRANSFER_ETH * NEAR_THRESHOLD_MAX_MULTIPLIER,
                        "window_minutes": int(NEAR_THRESHOLD_WINDOW.total_seconds() / 60),
                    },
                )
            )
            break

    return patterns
