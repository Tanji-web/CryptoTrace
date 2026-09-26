"""Graph-based VASP attribution helpers."""
from __future__ import annotations

from typing import List, Optional, Tuple

import networkx as nx


def find_nearest_vasp(graph: nx.MultiDiGraph, target_address: str) -> Tuple[Optional[str], List[str]]:
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
    return best_vasp, best_path
