"""Graph construction and bounded wallet traversal."""
from __future__ import annotations

from collections import deque
from typing import Any, Dict, List, Optional, Tuple

import networkx as nx

from cryptotrace.config import (
    MAX_CANDIDATES_PER_WALLET,
    MAX_GRAPH_NODES,
    MAX_LIVE_API_CALLS,
    MIN_TRANSFER_ETH,
)
from cryptotrace.ingestion.etherscan import fetch_live_for_address, finalize_candidates
from cryptotrace.ingestion.mock import transactions_for_mock_address
from cryptotrace.models import TraceOutcome, TransactionCandidate
from cryptotrace.registry import lookup_vasp
from cryptotrace.utils import is_valid_eth_address


def _add_node(graph: nx.MultiDiGraph, address: str, target_address: str) -> None:
    vasp = lookup_vasp(address)
    graph.add_node(
        address,
        is_vasp=vasp is not None,
        vasp_name=vasp["name"] if vasp else None,
        vasp_type=vasp["type"] if vasp else None,
        vasp_verified=(vasp.get("verification_status") == "verified") if vasp else False,
        is_target=(address == target_address),
    )


def _edge_data(tx: TransactionCandidate) -> Dict[str, Any]:
    return {
        "asset_type": tx.asset_type, "asset_symbol": tx.asset_symbol, "amount": tx.amount,
        "tx_hash": tx.tx_hash, "timestamp": tx.timestamp.isoformat(), "block_number": tx.block_number,
        "transaction_type": tx.transaction_type, "token_contract": tx.token_contract,
        "token_decimals": tx.token_decimals, "token_raw_amount": tx.token_raw_amount,
    }


def trace_wallet(target_address: str, max_hops: int = 2) -> TraceOutcome:
    target_address = target_address.lower()
    graph = nx.MultiDiGraph()
    _add_node(graph, target_address, target_address)
    queue: deque[Tuple[str, int]] = deque([(target_address, 0)])
    visited: set[str] = set()
    transactions_by_node: Dict[str, List[TransactionCandidate]] = {}
    api_calls = [0]
    mock_mode = False
    live_failure = False
    overall_source = "live"
    totals = {
        "examined": 0,
        "included": 0,
        "below": 0,
        "unpriced_token": 0,
        "candidate_limit": 0,
        "non_economic_contract_calls": 0,
        "other_filtered": 0,
        "contract": 0,
        "internal": 0,
        "erc20": 0,
    }
    truncation_reason: Optional[str] = None
    depth_stop_reason: Optional[str] = None
    partial_data = False
    api_warnings: List[str] = []
    seen_edge_keys: set[Tuple[str, str, Optional[str], str, str]] = set()

    while queue:
        current, hop = queue.popleft()
        if current in visited:
            continue
        visited.add(current)

        if hop >= max_hops:
            continue
        if len(graph.nodes) >= MAX_GRAPH_NODES:
            truncation_reason = "max_nodes"
            break

        if mock_mode:
            txs = transactions_for_mock_address(current, target_address, max_hops)
            fetch = finalize_candidates(txs)
        else:
            if api_calls[0] >= MAX_LIVE_API_CALLS:
                truncation_reason = "max_api_calls"
                break

            fetch = fetch_live_for_address(current, api_calls)
            if fetch.partial_data:
                partial_data = True
                api_warnings.extend(fetch.api_warnings)

            if fetch.error and current == target_address and not fetch.transactions:
                mock_mode = True
                overall_source = "mock"
                api_warnings = ["Live API unavailable; deterministic mock data used."]
                txs = transactions_for_mock_address(current, target_address, max_hops)
                fetch = finalize_candidates(txs)
                partial_data = False
            elif fetch.error and current != target_address:
                api_warnings.extend(fetch.api_warnings)
                live_failure = True
                depth_stop_reason = depth_stop_reason or "api_error"

        transactions_by_node[current] = fetch.transactions
        totals["examined"] += fetch.examined
        totals["below"] += fetch.filtered_below_threshold
        totals["unpriced_token"] += fetch.unpriced_token
        totals["candidate_limit"] += fetch.candidate_limit
        totals["non_economic_contract_calls"] += fetch.non_economic_contract_calls
        totals["other_filtered"] += fetch.other_filtered
        totals["contract"] += fetch.contract_interactions
        totals["internal"] += fetch.internal_eth_transactions
        totals["erc20"] += fetch.erc20_transactions

        for tx in fetch.transactions:
            if not tx.eligible:
                continue
            edge_key = (
                tx.tx_hash,
                tx.asset_type,
                tx.token_contract,
                tx.from_address,
                tx.to_address,
            )
            if edge_key in seen_edge_keys:
                continue
            neighbor = tx.to_address if tx.from_address == current else tx.from_address
            if not is_valid_eth_address(neighbor):
                totals["other_filtered"] += 1
                continue
            if len(graph.nodes) >= MAX_GRAPH_NODES and neighbor not in graph:
                totals["other_filtered"] += 1
                truncation_reason = "max_nodes"
                break

            seen_edge_keys.add(edge_key)
            _add_node(graph, neighbor, target_address)
            graph.add_edge(tx.from_address, tx.to_address, **_edge_data(tx))
            totals["included"] += 1
            if neighbor not in visited:
                queue.append((neighbor, hop + 1))

        if truncation_reason:
            break
        if not fetch.transactions and hop < max_hops:
            depth_stop_reason = depth_stop_reason or (
                "api_error" if fetch.error else "no_eligible_transactions"
            )

    try:
        distances = nx.single_source_shortest_path_length(
            graph.to_undirected(), target_address, cutoff=max_hops
        )
        reached_hops = max(distances.values()) if distances else 0
    except (nx.NetworkXError, KeyError):
        reached_hops = 0

    if reached_hops >= max_hops:
        depth_stop_reason = None
    elif truncation_reason:
        depth_stop_reason = truncation_reason
    elif live_failure:
        depth_stop_reason = "api_error"
    elif not graph.edges:
        depth_stop_reason = depth_stop_reason or "no_transactions"
    else:
        depth_stop_reason = depth_stop_reason or "no_eligible_transactions"

    if not graph.edges and overall_source == "live" and not mock_mode:
        overall_source = "live_no_eligible_transactions"
    if live_failure:
        overall_source = "live_api_error"

    # Unpriced ERC-20 transfers are retained as graph evidence, so they are
    # informational rather than part of the filtered-count arithmetic.
    filtered = (
        totals["below"]
        + totals["candidate_limit"]
        + totals["non_economic_contract_calls"]
        + totals["other_filtered"]
    )
    if totals["examined"] != totals["included"] + filtered:
        totals["other_filtered"] += max(
            0, totals["examined"] - totals["included"] - filtered
        )
        filtered = (
            totals["below"]
            + totals["candidate_limit"]
            + totals["non_economic_contract_calls"]
            + totals["other_filtered"]
        )

    api_warnings = list(dict.fromkeys(api_warnings))
    analysis = {
        "minimum_transfer_eth": MIN_TRANSFER_ETH,
        "transactions_examined": totals["examined"],
        "transactions_included": totals["included"],
        "transactions_filtered": filtered,
        "filtered_below_eth_threshold": totals["below"],
        "unpriced_token_transactions": totals["unpriced_token"],
        "filtered_candidate_limit": totals["candidate_limit"],
        "filtered_non_economic_contract_calls": totals["non_economic_contract_calls"],
        "filtered_other": totals["other_filtered"],
        "contract_interactions": totals["contract"],
        "internal_eth_transactions": totals["internal"],
        "erc20_transactions": totals["erc20"],
        "limits": {
            "max_nodes": MAX_GRAPH_NODES,
            "max_api_calls": MAX_LIVE_API_CALLS,
            "max_candidates_per_wallet": MAX_CANDIDATES_PER_WALLET,
        },
        "truncated": truncation_reason is not None,
        "truncation_reason": truncation_reason,
        "live_api_calls": api_calls[0],
        "partial_data": partial_data,
        "api_warnings": api_warnings,
    }

    from cryptotrace.graph.attribution import find_nearest_vasp
    nearest_vasp, path, vasp_direction, path_hops = find_nearest_vasp(graph, target_address)
    return TraceOutcome(
        graph=graph,
        target_address=target_address,
        data_source=overall_source,
        vasp_address=nearest_vasp,
        path=path,
        vasp_direction=vasp_direction,
        path_hops=path_hops,
        requested_hops=max_hops,
        reached_hops=reached_hops,
        depth_stop_reason=depth_stop_reason,
        analysis=analysis,
        transactions_by_node=transactions_by_node,
    )
