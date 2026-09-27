"""Graph-based VASP attribution helpers."""
from __future__ import annotations

from typing import List, Optional, Tuple

import networkx as nx

from cryptotrace.models import PathHopEvidence


def _hop_direction(outgoing_tx_hashes: List[str], incoming_tx_hashes: List[str]) -> str:
    if outgoing_tx_hashes and incoming_tx_hashes:
        return "mixed"
    if outgoing_tx_hashes:
        return "outbound"
    if incoming_tx_hashes:
        return "inbound"
    return "unknown"


def _path_evidence(graph: nx.MultiDiGraph, path: List[str]) -> Tuple[str, List[PathHopEvidence]]:
    hops: List[PathHopEvidence] = []
    directions: List[str] = []

    for from_address, to_address in zip(path, path[1:]):
        outgoing_tx_hashes: List[str] = []
        incoming_tx_hashes: List[str] = []

        if graph.has_edge(from_address, to_address):
            for _, data in graph[from_address][to_address].items():
                tx_hash = data.get("tx_hash")
                if tx_hash:
                    outgoing_tx_hashes.append(tx_hash)

        if graph.has_edge(to_address, from_address):
            for _, data in graph[to_address][from_address].items():
                tx_hash = data.get("tx_hash")
                if tx_hash:
                    incoming_tx_hashes.append(tx_hash)

        hop_direction = _hop_direction(outgoing_tx_hashes, incoming_tx_hashes)
        directions.append(hop_direction)
        hops.append(
            PathHopEvidence(
                from_address=from_address,
                to_address=to_address,
                direction=hop_direction,
                outgoing_tx_hashes=outgoing_tx_hashes,
                incoming_tx_hashes=incoming_tx_hashes,
            )
        )

    if directions and all(direction == "outbound" for direction in directions):
        overall_direction = "outbound"
    elif directions and all(direction == "inbound" for direction in directions):
        overall_direction = "inbound"
    elif any(direction != "unknown" for direction in directions):
        overall_direction = "mixed"
    else:
        overall_direction = "unknown"

    return overall_direction, hops


def find_nearest_vasp(
    graph: nx.MultiDiGraph,
    target_address: str,
) -> Tuple[Optional[str], List[str], Optional[str], List[PathHopEvidence]]:
    """Find the nearest VASP and surface direction evidence for the selected path.

    The existing shortest-path proximity rule is intentionally unchanged. Direction
    is calculated separately so the application can distinguish outbound, inbound,
    mixed, or unknown flow along that selected path without changing score arithmetic.
    """
    undirected = graph.to_undirected()
    vasp_nodes = [n for n, data in graph.nodes(data=True) if data.get("is_vasp")]
    best_vasp: Optional[str] = None
    best_path: List[str] = []

    for vasp_node in vasp_nodes:
        if not nx.has_path(undirected, target_address, vasp_node):
            continue
        candidate = nx.shortest_path(undirected, target_address, vasp_node)
        if not best_path or len(candidate) < len(best_path):
            best_path, best_vasp = candidate, vasp_node

    if not best_path:
        return None, [], None, []

    direction, path_hops = _path_evidence(graph, best_path)
    return best_vasp, best_path, direction, path_hops
