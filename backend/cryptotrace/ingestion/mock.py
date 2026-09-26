"""Deterministic demo/mock transaction source."""
from __future__ import annotations

import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import List, Tuple

from cryptotrace.models import TransactionCandidate
from cryptotrace.registry import lookup_vasp


def _seeded_random(seed_key: str) -> random.Random:
    digest = hashlib.sha256(seed_key.encode("utf-8")).hexdigest()
    return random.Random(int(digest[:16], 16))


def _fake_address(rng: random.Random) -> str:
    return "0x" + "".join(rng.choice("0123456789abcdef") for _ in range(40))


def _fake_tx_hash(rng: random.Random) -> str:
    return "0x" + "".join(rng.choice("0123456789abcdef") for _ in range(64))


def generate_mock_transactions(
    target_address: str,
    max_hops: int,
) -> Tuple[List[TransactionCandidate], str]:
    rng = _seeded_random(target_address)
    vasp_addresses = [
        address for address in (lookup_vasp(a) and a for a in (
            "0x28c6c06298d514db089934071355e5743bf21d60",
            "0x503209a779226e6392913734c7601313380f7192",
            "0x2910543af39aba0cd09d90708cc63a1196b9e498",
            "0x27029817b2f2a12111e9f1c4b0a6a8f673f84824",
        )) if address
    ]
    vasp_address = vasp_addresses[rng.randrange(len(vasp_addresses))]
    chain_length = max(2, max_hops)
    intermediates = [_fake_address(rng) for _ in range(chain_length - 1)]
    chain = [target_address.lower()] + intermediates + [vasp_address]
    base_time = datetime.now(timezone.utc) - timedelta(days=chain_length * 3)
    txs: List[TransactionCandidate] = []

    for i in range(len(chain) - 1):
        eth = round(rng.uniform(0.0001, 4.5), 6)
        ts = base_time + timedelta(hours=i * rng.randint(6, 48))
        txs.append(TransactionCandidate(
            from_address=chain[i], to_address=chain[i + 1], asset_type="native_eth", asset_symbol="ETH",
            amount=eth, tx_hash=_fake_tx_hash(rng), timestamp=ts,
            block_number=18_500_000 + i * rng.randint(500, 5000), transaction_type="native_eth",
        ))

    for _ in range(rng.randint(0, 2)):
        noise = _fake_address(rng)
        ts = base_time - timedelta(days=rng.randint(1, 10))
        txs.append(TransactionCandidate(
            from_address=noise, to_address=target_address.lower(), asset_type="native_eth", asset_symbol="ETH",
            amount=round(rng.uniform(0.000001, 0.0004), 6),
            tx_hash=_fake_tx_hash(rng), timestamp=ts, block_number=18_480_000,
            transaction_type="native_eth",
        ))
    return txs, vasp_address


def transactions_for_mock_address(address: str, target_address: str, max_hops: int) -> List[TransactionCandidate]:
    all_txs, _ = generate_mock_transactions(target_address, max_hops)
    return [tx for tx in all_txs if tx.from_address == address or tx.to_address == address]
