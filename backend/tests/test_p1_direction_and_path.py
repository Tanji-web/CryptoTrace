import networkx as nx

from cryptotrace.graph.attribution import find_nearest_vasp
from cryptotrace.graph.tracer import trace_wallet
from cryptotrace.registry import KNOWN_VASP_WALLETS
from cryptotrace.services.response import build_trace_response

TARGET = "0x1111111111111111111111111111111111111111"
VASPS = list(KNOWN_VASP_WALLETS)
COINBASE = "0x503209a779226e6392913734c7601313380f7192"


def _edge(graph, source, target, tx_hash):
    graph.add_edge(source, target, tx_hash=tx_hash)


def test_direction_is_outbound_for_target_to_vasp_path():
    graph = nx.MultiDiGraph()
    _edge(graph, TARGET, COINBASE, "0xoutbound")
    graph.nodes[COINBASE]["is_vasp"] = True

    vasp, path, direction, hops = find_nearest_vasp(graph, TARGET)

    assert vasp == COINBASE
    assert path == [TARGET, COINBASE]
    assert direction == "outbound"
    assert hops[0].direction == "outbound"
    assert hops[0].outgoing_tx_hashes == ["0xoutbound"]
    assert hops[0].incoming_tx_hashes == []


def test_direction_is_inbound_for_vasp_to_target_path():
    graph = nx.MultiDiGraph()
    _edge(graph, COINBASE, TARGET, "0xinbound")
    graph.nodes[COINBASE]["is_vasp"] = True

    vasp, path, direction, hops = find_nearest_vasp(graph, TARGET)

    assert vasp == COINBASE
    assert path == [TARGET, COINBASE]
    assert direction == "inbound"
    assert hops[0].incoming_tx_hashes == ["0xinbound"]
    assert hops[0].outgoing_tx_hashes == []


def test_direction_is_mixed_when_both_directions_exist_on_path_hop():
    graph = nx.MultiDiGraph()
    _edge(graph, TARGET, COINBASE, "0xforward")
    _edge(graph, COINBASE, TARGET, "0xreverse")
    graph.nodes[COINBASE]["is_vasp"] = True

    vasp, path, direction, hops = find_nearest_vasp(graph, TARGET)

    assert vasp == COINBASE
    assert path == [TARGET, COINBASE]
    assert direction == "mixed"
    assert hops[0].direction == "mixed"
    assert set(hops[0].outgoing_tx_hashes) == {"0xforward"}
    assert set(hops[0].incoming_tx_hashes) == {"0xreverse"}


def test_trace_response_exposes_exact_path_transaction_hashes():
    response = build_trace_response(trace_wallet("0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef", 2), 2)

    assert response.summary.path
    assert response.summary.vasp_direction in {"outbound", "inbound", "mixed", "unknown"}
    assert len(response.summary.path_hops) == len(response.summary.path) - 1

    edge_hashes = {edge.tx_hash for edge in response.edges}
    for hop in response.summary.path_hops:
        assert hop.from_ in response.summary.path
        assert hop.to in response.summary.path
        assert set(hop.outgoing_tx_hashes + hop.incoming_tx_hashes).issubset(edge_hashes)
