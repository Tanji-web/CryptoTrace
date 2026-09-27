from datetime import datetime, timedelta, timezone

import networkx as nx

from cryptotrace.graph.patterns import detect_pattern_indicators
from cryptotrace.models import TransactionCandidate


ADDRS = [f"0x{i:040x}" for i in range(1, 12)]


def tx(sender, receiver, amount, when, index):
    return TransactionCandidate(
        from_address=sender,
        to_address=receiver,
        asset_type="native_eth",
        asset_symbol="ETH",
        amount=amount,
        tx_hash=f"0x{index:064x}",
        timestamp=when,
        block_number=18_500_000 + index,
        transaction_type="native_eth",
        eligible=True,
    )


def add_edge(g, candidate):
    g.add_edge(
        candidate.from_address,
        candidate.to_address,
        asset_type=candidate.asset_type,
        asset_symbol=candidate.asset_symbol,
        amount=candidate.amount,
        tx_hash=candidate.tx_hash,
        timestamp=candidate.timestamp.isoformat(),
        block_number=candidate.block_number,
        transaction_type=candidate.transaction_type,
    )


def pattern_keys(patterns):
    return {pattern["key"] for pattern in patterns}


def test_fan_out_and_fan_in_are_detected():
    g = nx.MultiDiGraph()
    now = datetime(2026, 9, 27, 12, 0, tzinfo=timezone.utc)
    for i, dest in enumerate(ADDRS[1:4], start=1):
        add_edge(g, tx(ADDRS[0], dest, 0.8, now + timedelta(minutes=i), i))
    for i, source in enumerate(ADDRS[4:7], start=4):
        add_edge(g, tx(source, ADDRS[7], 0.8, now + timedelta(minutes=i), i))

    patterns = detect_pattern_indicators(g, [], {})
    keys = pattern_keys(patterns)
    assert "fan_out" in keys
    assert "fan_in" in keys


def test_rapid_forwarding_is_detected():
    g = nx.MultiDiGraph()
    now = datetime(2026, 9, 27, 12, 0, tzinfo=timezone.utc)
    incoming = tx(ADDRS[0], ADDRS[1], 1.0, now, 1)
    outgoing = tx(ADDRS[1], ADDRS[2], 0.9, now + timedelta(minutes=5), 2)
    add_edge(g, incoming)
    add_edge(g, outgoing)

    patterns = detect_pattern_indicators(g, [ADDRS[0], ADDRS[1], ADDRS[2]], {})
    assert "rapid_forwarding" in pattern_keys(patterns)


def test_long_route_is_detected():
    g = nx.MultiDiGraph()
    now = datetime(2026, 9, 27, 12, 0, tzinfo=timezone.utc)
    path = [ADDRS[0], ADDRS[1], ADDRS[2], ADDRS[3]]
    for index, (a, b) in enumerate(zip(path, path[1:]), start=1):
        add_edge(g, tx(a, b, 1.0, now + timedelta(hours=index), index))

    patterns = detect_pattern_indicators(g, path, {})
    long_route = [p for p in patterns if p["key"] == "long_route"]
    assert len(long_route) == 1
    assert long_route[0]["evidence"]["hop_count"] == 3


def test_repeated_routing_and_near_threshold_cluster_are_detected():
    g = nx.MultiDiGraph()
    now = datetime(2026, 9, 27, 12, 0, tzinfo=timezone.utc)
    intermediary = ADDRS[1]
    for index, source in enumerate([ADDRS[0], ADDRS[2]], start=1):
        add_edge(g, tx(source, intermediary, 1.0, now + timedelta(minutes=index), index))
    for index, dest in enumerate([ADDRS[3], ADDRS[4]], start=3):
        add_edge(g, tx(intermediary, dest, 0.0007, now + timedelta(minutes=index), index))

    near = [
        tx(intermediary, ADDRS[5], 0.0006, now + timedelta(minutes=10), 5),
        tx(intermediary, ADDRS[6], 0.0007, now + timedelta(minutes=20), 6),
        tx(intermediary, ADDRS[7], 0.0008, now + timedelta(minutes=30), 7),
    ]
    tx_map = {intermediary: near}
    for item in near:
        add_edge(g, item)

    patterns = detect_pattern_indicators(g, [ADDRS[0], intermediary, ADDRS[3]], tx_map)
    keys = pattern_keys(patterns)
    assert "repeated_routing" in keys
    assert "near_threshold_splitting" in keys
