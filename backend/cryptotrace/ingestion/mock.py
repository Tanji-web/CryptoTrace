"""Deterministic demo/mock transaction source.

The mock is intentionally designed as a small investigation dataset rather than
random noise.  Its topology changes with the requested hop depth so every
supported depth (1-3) produces a meaningful VASP path and at least one
investigation pattern can be demonstrated without a live Etherscan key.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List, Tuple

from cryptotrace.models import TransactionCandidate


# Stable demo accounts.  These are intentionally synthetic and are not meant to
# represent real user-controlled wallets.
ACCOUNT_A = "0x1111111111111111111111111111111111111111"
ACCOUNT_B = "0x2222222222222222222222222222222222222222"
ACCOUNT_C = "0x3333333333333333333333333333333333333333"
ACCOUNT_D = "0x4444444444444444444444444444444444444444"
ACCOUNT_E = "0x5555555555555555555555555555555555555555"
ACCOUNT_F = "0x6666666666666666666666666666666666666666"
ACCOUNT_G = "0x7777777777777777777777777777777777777777"
ACCOUNT_H = "0x8888888888888888888888888888888888888888"
ACCOUNT_I = "0x9999999999999999999999999999999999999999"
ACCOUNT_J = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

COINBASE = "0x503209a779226e6392913734c7601313380f7192"
KRAKEN = "0x2910543af39aba0cd09d90708cc63a1196b9e498"

BASE_TIME = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
BASE_BLOCK = 18_500_000


def _tx(
    from_address: str,
    to_address: str,
    amount: float,
    tx_id: int,
    *,
    minutes: int,
    block_offset: int,
) -> TransactionCandidate:
    return TransactionCandidate(
        from_address=from_address.lower(),
        to_address=to_address.lower(),
        asset_type="native_eth",
        asset_symbol="ETH",
        amount=amount,
        tx_hash="0x" + f"{tx_id:02x}" + "a" * 62,
        timestamp=BASE_TIME + timedelta(minutes=minutes),
        block_number=BASE_BLOCK + block_offset,
        transaction_type="native_eth",
    )


def _build_hop_one_graph(target: str) -> Tuple[List[TransactionCandidate], str]:
    """Direct VASP path plus fan-in/fan-out and near-threshold demo evidence."""
    txs = [
        # Core fan-out from target.
        _tx(target, ACCOUNT_A, 2.50, 1, minutes=0, block_offset=100),
        _tx(target, ACCOUNT_B, 1.75, 2, minutes=3, block_offset=200),
        _tx(target, ACCOUNT_C, 1.20, 3, minutes=6, block_offset=300),
        # Near-threshold cluster from the same wallet.
        _tx(target, ACCOUNT_D, 0.0006, 4, minutes=10, block_offset=400),
        _tx(target, ACCOUNT_E, 0.0007, 5, minutes=20, block_offset=500),
        _tx(target, ACCOUNT_F, 0.0008, 6, minutes=30, block_offset=600),
        # Three incoming counterparties to target -> fan-in.
        _tx(ACCOUNT_G, target, 0.15, 7, minutes=-30, block_offset=50),
        _tx(ACCOUNT_H, target, 0.22, 8, minutes=-20, block_offset=60),
        _tx(ACCOUNT_I, target, 0.31, 9, minutes=-10, block_offset=70),
        # Direct VASP path guarantees hop-1 demo behavior.
        _tx(target, COINBASE, 0.80, 10, minutes=40, block_offset=700),
        # One filtered transfer so the demo still exercises the threshold logic.
        _tx(ACCOUNT_J, target, 0.0002, 11, minutes=-40, block_offset=40),
    ]
    return txs, COINBASE


def _build_hop_two_graph(target: str) -> Tuple[List[TransactionCandidate], str]:
    """Two-hop VASP path with fan-in, rapid forwarding and repeated routing."""
    txs = [
        # Target fan-out + threshold cluster.
        _tx(target, ACCOUNT_A, 2.50, 101, minutes=0, block_offset=100),
        _tx(target, ACCOUNT_B, 1.75, 102, minutes=180, block_offset=200),
        _tx(target, ACCOUNT_C, 1.20, 103, minutes=360, block_offset=300),
        _tx(target, ACCOUNT_D, 0.0006, 104, minutes=10, block_offset=400),
        _tx(target, ACCOUNT_E, 0.0007, 105, minutes=20, block_offset=500),
        _tx(target, ACCOUNT_F, 0.0008, 106, minutes=30, block_offset=600),
        # Three inbound counterparties to target -> fan-in.
        _tx(ACCOUNT_G, target, 0.15, 107, minutes=-30, block_offset=50),
        _tx(ACCOUNT_H, target, 0.22, 108, minutes=-20, block_offset=60),
        _tx(ACCOUNT_I, target, 0.31, 109, minutes=-10, block_offset=70),
        # A has two inbound + two outbound edges -> repeated routing.
        _tx(ACCOUNT_G, ACCOUNT_A, 0.60, 110, minutes=-5, block_offset=800),
        _tx(ACCOUNT_A, COINBASE, 0.80, 111, minutes=5, block_offset=900),
        _tx(ACCOUNT_A, ACCOUNT_E, 0.40, 112, minutes=7, block_offset=950),
        # B and C also feed the VASP -> fan-in at the VASP node.
        _tx(ACCOUNT_B, COINBASE, 1.10, 113, minutes=185, block_offset=2_000),
        _tx(ACCOUNT_C, COINBASE, 0.90, 114, minutes=365, block_offset=3_000),
        # Filtered transfer retained for analysis visibility.
        _tx(ACCOUNT_J, target, 0.0002, 115, minutes=-40, block_offset=40),
    ]
    return txs, COINBASE


def _build_hop_three_graph(target: str) -> Tuple[List[TransactionCandidate], str]:
    """Three-hop route with long routing + repeated routing + rapid forwarding."""
    txs = [
        # Target fan-out + threshold cluster.
        _tx(target, ACCOUNT_A, 2.50, 201, minutes=0, block_offset=100),
        _tx(target, ACCOUNT_B, 1.75, 180, block_offset=200, minutes=180),
        _tx(target, ACCOUNT_D, 0.0006, 203, minutes=10, block_offset=300),
        _tx(target, ACCOUNT_E, 0.0007, 204, minutes=20, block_offset=400),
        _tx(target, ACCOUNT_F, 0.0008, 205, minutes=30, block_offset=500),
        # Fan-in to target.
        _tx(ACCOUNT_F, target, 0.15, 206, minutes=-30, block_offset=50),
        _tx(ACCOUNT_G, target, 0.22, 207, minutes=-20, block_offset=60),
        _tx(ACCOUNT_H, target, 0.31, 208, minutes=-10, block_offset=70),
        # Two inbound paths converge on C; C has three outbound routes.
        _tx(ACCOUNT_A, ACCOUNT_C, 1.40, 209, minutes=5, block_offset=6_000),
        _tx(ACCOUNT_B, ACCOUNT_C, 1.10, 210, minutes=185, block_offset=6_100),
        _tx(ACCOUNT_I, ACCOUNT_C, 0.60, 211, minutes=7, block_offset=6_200),
        _tx(ACCOUNT_C, KRAKEN, 0.65, 212, minutes=10, block_offset=7_000),
        _tx(ACCOUNT_C, ACCOUNT_E, 0.90, 213, minutes=12, block_offset=7_100),
        _tx(ACCOUNT_C, ACCOUNT_F, 0.35, 214, minutes=14, block_offset=7_200),
        # Filtered transfer retained for analysis visibility.
        _tx(ACCOUNT_J, target, 0.0002, 215, minutes=-40, block_offset=40),
    ]
    return txs, KRAKEN


def generate_mock_transactions(
    target_address: str,
    max_hops: int,
) -> Tuple[List[TransactionCandidate], str]:
    """Return a deterministic investigation dataset for the requested depth.

    Each supported hop depth has a VASP path reachable within that exact depth.
    The scenarios also contain above-threshold evidence for the pattern detector.
    """
    target = target_address.lower()
    if max_hops <= 1:
        return _build_hop_one_graph(target)
    if max_hops == 2:
        return _build_hop_two_graph(target)
    return _build_hop_three_graph(target)


def transactions_for_mock_address(
    address: str,
    target_address: str,
    max_hops: int,
) -> List[TransactionCandidate]:
    all_txs, _ = generate_mock_transactions(target_address, max_hops)
    normalized = address.lower()
    return [
        tx for tx in all_txs
        if tx.from_address == normalized or tx.to_address == normalized
    ]
