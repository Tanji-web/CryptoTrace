"""
CryptoTrace — VASP Attribution Portal
Backend service (FastAPI)

Heuristic Ethereum wallet tracing with a direct ETH transfer threshold.
Graph proximity to a known VASP is a lead, not proof of ownership, control, or identity.
"""
from __future__ import annotations

import hashlib
import io
import logging
import os
import random
import re
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import httpx
import networkx as nx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field, field_validator
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

load_dotenv()

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY", "").strip()
ETHERSCAN_BASE_URL = "https://api.etherscan.io/v2/api"
ETHERSCAN_TIMEOUT_SECONDS = 8.0
CORS_ORIGINS_RAW = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080")
CORS_ORIGINS = [x.strip() for x in CORS_ORIGINS_RAW.split(",") if x.strip()]

MAX_HOPS_ALLOWED = 3
MAX_GRAPH_NODES = int(os.getenv("MAX_GRAPH_NODES", "100"))
MAX_LIVE_API_CALLS = int(os.getenv("MAX_LIVE_API_CALLS", "30"))
MAX_CANDIDATES_PER_WALLET = int(os.getenv("MAX_CANDIDATES_PER_WALLET", "10"))
MIN_TRANSFER_ETH = 0.0005
MAX_TRANSACTIONS_PER_SOURCE = int(os.getenv("MAX_TRANSACTIONS_PER_SOURCE", "100"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("cryptotrace")
ETH_ADDRESS_PATTERN = re.compile(r"^0x[a-fA-F0-9]{40}$")

# --------------------------------------------------------------------------- #
# VASP registry
# --------------------------------------------------------------------------- #
# These are deliberately demo records. They must not be presented as verified
# production exchange addresses without an externally sourced intelligence feed.
KNOWN_VASP_WALLETS: Dict[str, Dict[str, str]] = {

    "0x28c6c06298d514db089934071355e5743bf21d60": {
        "name": "Binance",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "verified": "true",
        "last_verified": "",
        "notes": "Binance 14",
    },

    "0x503209a779226e6392913734c7601313380f7192": {
        "name": "Coinbase",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "verified": "true",
        "last_verified": "",
        "notes": "Coinbase Hot Wallet",
    },

    "0x2910543af39aba0cd09d90708cc63a1196b9e498": {
        "name": "Kraken",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "verified": "true",
        "last_verified": "",
        "notes": "Kraken Hot Wallet 1",
    },

    "0x27029817b2f2a12111e9f1c4b0a6a8f673f84824": {
        "name": "WazirX",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "verified": "true",
        "last_verified": "",
        "notes": "WazirX Hot Wallet / Deposit Sweeper",
    },

}


def _normalize_demo_address(raw: str) -> str:
    body = raw[2:] if raw.startswith("0x") else raw
    return "0x" + (body + "0" * 40)[:40]

KNOWN_VASP_WALLETS = {_normalize_demo_address(k): v for k, v in KNOWN_VASP_WALLETS.items()}


def lookup_vasp(address: str) -> Optional[Dict[str, str]]:
    return KNOWN_VASP_WALLETS.get(address.lower())

# --------------------------------------------------------------------------- #
# API models
# --------------------------------------------------------------------------- #
class TraceRequest(BaseModel):
    wallet_address: str = Field(..., description="Target Ethereum wallet address")
    max_hops: int = Field(2, ge=1, le=MAX_HOPS_ALLOWED)

    @field_validator("wallet_address")
    @classmethod
    def validate_address(cls, value: str) -> str:
        value = value.strip().lower()
        if not ETH_ADDRESS_PATTERN.match(value):
            raise ValueError("wallet_address must be a valid 0x-prefixed 40 hex character address")
        return value


class NodeModel(BaseModel):
    id: str
    label: str
    is_vasp: bool
    vasp_name: Optional[str] = None
    vasp_type: Optional[str] = None
    is_target: bool = False


class EdgeModel(BaseModel):
    from_: str = Field(..., alias="from")
    to: str
    asset_type: str = "unknown"
    asset_symbol: Optional[str] = None
    amount: float = 0.0
    tx_hash: str
    timestamp: str
    block_number: Optional[int] = None
    transaction_type: str = "unknown"
    token_contract: Optional[str] = None
    token_decimals: Optional[int] = None
    token_raw_amount: Optional[str] = None

    class Config:
        populate_by_name = True
        validate_by_name = True


class AnalysisModel(BaseModel):
    minimum_transfer_eth: float
    transactions_examined: int
    transactions_included: int
    transactions_filtered: int
    filtered_below_eth_threshold: int
    unpriced_token_transactions: int
    filtered_candidate_limit: int
    filtered_non_economic_contract_calls: int
    filtered_other: int
    contract_interactions: int
    internal_eth_transactions: int
    erc20_transactions: int
    limits: Dict[str, int]
    truncated: bool
    truncation_reason: Optional[str] = None
    live_api_calls: int
    partial_data: bool = False
    api_warnings: List[str] = Field(default_factory=list)


class AttributionSummary(BaseModel):
    target_wallet: str
    nearest_vasp: Optional[str]
    vasp_type: Optional[str]
    hop_count: Optional[int]
    requested_hops: int
    reached_hops: int
    depth_stop_reason: Optional[str] = None
    confidence_score: int
    risk_score: int
    data_source: str
    path: List[str]
    scoring_notes: List[str]
    disclaimer: str = (
        "This attribution is derived from heuristic graph analysis of transaction proximity. "
        "It does not constitute proof of wallet ownership, control, or identity, and must not "
        "be treated as a definitive or legal identification."
    )


class TraceResponse(BaseModel):
    nodes: List[NodeModel]
    edges: List[EdgeModel]
    summary: AttributionSummary
    analysis: AnalysisModel


class HealthResponse(BaseModel):
    status: str
    etherscan_key_configured: bool
    timestamp: str

# --------------------------------------------------------------------------- #
# Internal data types
# --------------------------------------------------------------------------- #
@dataclass
class TransactionCandidate:
    from_address: str
    to_address: str
    asset_type: str
    asset_symbol: Optional[str]
    amount: float
    tx_hash: str
    timestamp: datetime
    block_number: int
    token_contract: Optional[str] = None
    token_decimals: Optional[int] = None
    token_raw_amount: Optional[str] = None
    transaction_type: str = "unknown"
    eligible: bool = False
    filter_reason: Optional[str] = None
    priority: Tuple[int, int, float, float] = (0, 0, 0.0, 0.0)


@dataclass
class FetchResult:
    transactions: List[TransactionCandidate]
    source: str
    error: Optional[str] = None
    examined: int = 0
    filtered_below_threshold: int = 0
    unpriced_token: int = 0
    candidate_limit: int = 0
    non_economic_contract_calls: int = 0
    other_filtered: int = 0
    contract_interactions: int = 0
    internal_eth_transactions: int = 0
    erc20_transactions: int = 0
    partial_data: bool = False
    api_warnings: List[str] = field(default_factory=list)


@dataclass
class TraceOutcome:
    graph: nx.MultiDiGraph
    target_address: str
    data_source: str
    vasp_address: Optional[str]
    path: List[str]
    requested_hops: int
    reached_hops: int
    depth_stop_reason: Optional[str]
    analysis: Dict[str, Any]
    transactions_by_node: Dict[str, List[TransactionCandidate]] = field(default_factory=dict)

# --------------------------------------------------------------------------- #
# Address / formatting helpers
# --------------------------------------------------------------------------- #
def is_valid_eth_address(address: str) -> bool:
    return bool(ETH_ADDRESS_PATTERN.match(address.strip()))


def _shorten(value: str, keep: int = 6) -> str:
    if len(value) <= keep * 2 + 3:
        return value
    return f"{value[:keep]}...{value[-4:]}"


def _format_eth_amount(value: float) -> str:
    if value == 0:
        return "0 ETH"
    if value >= 1:
        text = f"{value:.2f}"
    elif value >= 0.000001:
        text = f"{value:.6f}"
    else:
        text = f"{value:.8f}"
    return f"{text} ETH"

# --------------------------------------------------------------------------- #
# Etherscan ingestion
# --------------------------------------------------------------------------- #
def _etherscan_get(action: str, address: str, api_calls: List[int]) -> Tuple[List[dict], Optional[str]]:
    if not ETHERSCAN_API_KEY:
        return [], "ETHERSCAN_API_KEY not configured"
    if api_calls[0] >= MAX_LIVE_API_CALLS:
        return [], "API limit"
    params = {
        "chainid": "1", "module": "account", "action": action,
        "address": address, "page": "1", "offset": str(MAX_TRANSACTIONS_PER_SOURCE),
        "sort": "desc", "apikey": ETHERSCAN_API_KEY,
    }
    try:
        response = httpx.get(ETHERSCAN_BASE_URL, params=params, timeout=ETHERSCAN_TIMEOUT_SECONDS)
        api_calls[0] += 1
        response.raise_for_status()
        payload = response.json()
    except httpx.TimeoutException:
        api_calls[0] += 1
        return [], "Etherscan request timed out"
    except httpx.HTTPStatusError as exc:
        api_calls[0] += 1
        return [], f"Etherscan HTTP {exc.response.status_code}"
    except (httpx.RequestError, ValueError) as exc:
        api_calls[0] += 1
        return [], f"Etherscan request error: {exc}"
    if not isinstance(payload, dict):
        return [], "Unexpected Etherscan response shape"
    if payload.get("status") == "0":
        msg = payload.get("message", "")
        result = payload.get("result")
        if msg in {"No transactions found", "No records found", "No transactions found for this address"}:
            return [], None
        return [], f"Etherscan error: {result if isinstance(result, str) else msg}"
    result = payload.get("result")
    if not isinstance(result, list):
        return [], "Unexpected Etherscan result payload"
    return result, None


def _parse_timestamp(value: Any) -> Optional[datetime]:
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc)
    except (ValueError, TypeError, OverflowError):
        return None


def _make_normal_candidate(item: dict) -> Optional[TransactionCandidate]:
    try:
        ts = _parse_timestamp(item.get("timeStamp"))
        if ts is None:
            return None
        sender = str(item["from"]).lower()
        receiver = str(item.get("to", "")).lower() or sender
        eth = int(item.get("value", "0")) / 1e18
        return TransactionCandidate(
            from_address=sender, to_address=receiver, asset_type="native_eth",
            asset_symbol="ETH", amount=eth,
            tx_hash=str(item.get("hash", "")), timestamp=ts,
            block_number=int(item.get("blockNumber", 0) or 0), transaction_type="native_eth",
        )
    except (KeyError, ValueError, TypeError):
        return None


def _make_internal_candidate(item: dict) -> Optional[TransactionCandidate]:
    try:
        ts = _parse_timestamp(item.get("timeStamp"))
        if ts is None:
            return None
        sender = str(item["from"]).lower()
        receiver = str(item.get("to", "")).lower()
        eth = int(item.get("value", "0")) / 1e18
        return TransactionCandidate(
            from_address=sender, to_address=receiver, asset_type="internal_eth",
            asset_symbol="ETH", amount=eth,
            tx_hash=str(item.get("hash", "")), timestamp=ts,
            block_number=int(item.get("blockNumber", 0) or 0), transaction_type="internal_eth",
        )
    except (KeyError, ValueError, TypeError):
        return None


def _make_erc20_candidate(item: dict) -> Optional[TransactionCandidate]:
    try:
        ts = _parse_timestamp(item.get("timeStamp"))
        if ts is None:
            return None
        sender = str(item["from"]).lower()
        receiver = str(item.get("to", "")).lower()
        decimals = int(item.get("tokenDecimal", "0") or 0)
        raw = str(item.get("value", "0"))
        amount = int(raw) / (10 ** decimals) if decimals >= 0 else 0.0
        return TransactionCandidate(
            from_address=sender, to_address=receiver, asset_type="erc20",
            asset_symbol=str(item.get("tokenSymbol") or "TOKEN"), amount=amount,
            tx_hash=str(item.get("hash", "")), timestamp=ts,
            block_number=int(item.get("blockNumber", 0) or 0),
            token_contract=str(item.get("contractAddress", "")).lower() or None,
            token_decimals=decimals, token_raw_amount=raw, transaction_type="erc20",
        )
    except (KeyError, ValueError, TypeError):
        return None


def _value_and_filter(candidate: TransactionCandidate) -> None:
    """Apply the direct blockchain-amount qualification rule."""
    if candidate.asset_type in {"native_eth", "internal_eth"}:
        if candidate.amount >= MIN_TRANSFER_ETH:
            candidate.eligible = True
            candidate.filter_reason = "included"
        else:
            candidate.eligible = False
            candidate.filter_reason = "below_eth_threshold"
    elif candidate.asset_type == "erc20":
        # ERC-20 amounts are intentionally kept as token metadata. Without a
        # token-to-ETH conversion, they cannot participate in the ETH rule.
        candidate.eligible = False
        candidate.filter_reason = "unpriced_token"
    else:
        candidate.eligible = False
        candidate.filter_reason = "other_filtered"

    vasp_bonus = 1 if lookup_vasp(candidate.to_address) or lookup_vasp(candidate.from_address) else 0
    asset_rank = {"native_eth": 3, "internal_eth": 2, "erc20": 1, "contract_interaction": 0}.get(candidate.asset_type, 0)
    recency = candidate.timestamp.timestamp()
    amount_priority = candidate.amount if candidate.asset_type in {"native_eth", "internal_eth"} else 0.0
    candidate.priority = (vasp_bonus, asset_rank, recency, amount_priority)


def _finalize_candidates(
    candidates: List[TransactionCandidate],
) -> FetchResult:
    """Classify each candidate exactly once, then cap eligible ETH candidates."""
    below = unpriced_token = candidate_limit = contract_calls = other_filtered = 0
    internal_count = erc20_count = 0

    for candidate in candidates:
        if candidate.asset_type in {"native_eth", "internal_eth"} and candidate.amount == 0:
            candidate.asset_type = "contract_interaction"
            candidate.transaction_type = "contract_interaction"
            candidate.eligible = False
            candidate.filter_reason = "contract_interaction"
            contract_calls += 1
        else:
            _value_and_filter(candidate)

        if candidate.asset_type == "internal_eth":
            internal_count += 1
        elif candidate.asset_type == "erc20":
            erc20_count += 1

        if candidate.filter_reason == "below_eth_threshold":
            below += 1
        elif candidate.filter_reason == "unpriced_token":
            unpriced_token += 1
        elif candidate.filter_reason == "other_filtered":
            other_filtered += 1

    eligible = sorted(
        [candidate for candidate in candidates if candidate.eligible],
        key=lambda candidate: candidate.priority,
        reverse=True,
    )
    selected = eligible[:MAX_CANDIDATES_PER_WALLET]
    for candidate in eligible[len(selected):]:
        candidate.eligible = False
        candidate.filter_reason = "candidate_limit"
        candidate_limit += 1

    return FetchResult(
        transactions=selected,
        source="live",
        examined=len(candidates),
        filtered_below_threshold=below,
        unpriced_token=unpriced_token,
        candidate_limit=candidate_limit,
        non_economic_contract_calls=contract_calls,
        other_filtered=other_filtered,
        contract_interactions=contract_calls,
        internal_eth_transactions=internal_count,
        erc20_transactions=erc20_count,
    )

def _fetch_live_for_address(address: str, api_calls: List[int]) -> FetchResult:
    all_candidates: List[TransactionCandidate] = []
    errors: List[str] = []
    source_names = [
        ("normal transactions", "txlist"),
        ("internal ETH transfers", "txlistinternal"),
        ("ERC-20 transfers", "tokentx"),
    ]
    source_failures = 0

    for source_name, action in source_names:
        items, err = _etherscan_get(action, address, api_calls)
        if err:
            errors.append(f"{source_name} source unavailable: {err}")
            source_failures += 1
            continue
        for item in items:
            if action == "txlist":
                candidate = _make_normal_candidate(item)
            elif action == "txlistinternal":
                candidate = _make_internal_candidate(item)
            else:
                candidate = _make_erc20_candidate(item)
            if candidate:
                all_candidates.append(candidate)

    # Preserve separate blockchain transfers. A shared transaction hash is not
    # enough to merge normal ETH, internal ETH, and token transfer events.
    dedup: Dict[Tuple[str, str, Optional[str], str, str], TransactionCandidate] = {}
    for candidate in all_candidates:
        if not is_valid_eth_address(candidate.from_address) or not is_valid_eth_address(candidate.to_address):
            continue
        key = (
            candidate.tx_hash,
            candidate.asset_type,
            candidate.token_contract,
            candidate.from_address,
            candidate.to_address,
        )
        dedup[key] = candidate
    all_candidates = list(dedup.values())

    finalized = _finalize_candidates(all_candidates)
    warnings = list(dict.fromkeys(errors))
    partial_data = source_failures > 0
    all_sources_failed = source_failures == len(source_names)
    finalized.source = "live"
    finalized.error = "; ".join(warnings) if all_sources_failed else None
    finalized.partial_data = partial_data
    finalized.api_warnings = warnings
    return finalized

# --------------------------------------------------------------------------- #
# Deterministic mock data
# --------------------------------------------------------------------------- #
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

    target_address = target_address.lower()

    # Demo accounts
    account_a = "0x1111111111111111111111111111111111111111"
    account_b = "0x2222222222222222222222222222222222222222"
    account_c = "0x3333333333333333333333333333333333333333"
    account_d = "0x4444444444444444444444444444444444444444"
    account_e = "0x5555555555555555555555555555555555555555"
    account_f = "0x6666666666666666666666666666666666666666"

    # VASPs
    coinbase = "0x503209a779226e6392913734c7601313380f7192" 
    kraken = "0x2910543af39aba0cd09d90708cc63a1196b9e498"

    base_time = datetime.now(timezone.utc) - timedelta(days=3)
    base_block = 18_500_000

    transactions: List[TransactionCandidate] = []

    def add_tx(
        from_address: str,
        to_address: str,
        value_eth: float,
        tx_id: int,
        hours: int,
        block_offset: int,
    ) -> None:
        transactions.append(
            TransactionCandidate(
                from_address=from_address,
                to_address=to_address,
                asset_type="native_eth",
                asset_symbol="ETH",
                amount=value_eth,
                tx_hash="0x" + f"{tx_id:02x}" + "a" * 62,
                timestamp=base_time + timedelta(hours=hours),
                block_number=base_block + block_offset,
                transaction_type="native_eth",
            )
        )

    add_tx(
        target_address,
        account_a,
        2.50,
        1,
        0,
        100,
    )

    add_tx(
        target_address,
        account_b,
        1.75,
        2,
        3,
        200,
    )

    add_tx(
        account_a,
        account_c,
        1.40,
        3,
        24,
        6000,
    )

    add_tx(
        account_a,
        coinbase,
        0.80,
        4,
        28,
        6500,
    )

    add_tx(
        account_c,
        account_e,
        0.90,
        5,
        48,
        11000,
    )

    add_tx(
        account_c,
        account_f,
        0.35,
        6,
        52,
        11500,
    )

    add_tx(
        account_b,
        account_d,
        1.10,
        7,
        50,
        12000,
    )

    add_tx(
        account_d,
        kraken,
        0.65,
        8,
        58,
        12500,
    )

    add_tx(
        "0x7777777777777777777777777777777777777777",
        target_address,
        0.15,
        9,
        -12,
        -1000,
    )

    return transactions, coinbase

def transactions_for_mock_address(address: str, target_address: str, max_hops: int) -> List[TransactionCandidate]:
    all_txs, _ = generate_mock_transactions(target_address, max_hops)
    return [tx for tx in all_txs if tx.from_address == address or tx.to_address == address]

# --------------------------------------------------------------------------- #
# Graph engine
# --------------------------------------------------------------------------- #
def _add_node(graph: nx.MultiDiGraph, address: str, target_address: str) -> None:
    vasp = lookup_vasp(address)
    # update_node attributes as well as creating it. NetworkX can implicitly
    # create endpoint nodes when an edge is added, so a later pass must still
    # classify those nodes correctly.
    graph.add_node(
        address,
        is_vasp=vasp is not None,
        vasp_name=vasp["name"] if vasp else None,
        vasp_type=vasp["type"] if vasp else None,
        vasp_verified=(vasp.get("verified") == "true") if vasp else False,
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
            fetch = _finalize_candidates(txs)
        else:
            if api_calls[0] >= MAX_LIVE_API_CALLS:
                truncation_reason = "max_api_calls"
                break

            fetch = _fetch_live_for_address(current, api_calls)
            if fetch.partial_data:
                partial_data = True
                api_warnings.extend(fetch.api_warnings)

            # If every Etherscan source fails for the initial wallet, use the
            # deterministic mock dataset so a presentation can still proceed.
            # Do not silently replace otherwise useful live data with mock data.
            if fetch.error and current == target_address and not fetch.transactions:
                mock_mode = True
                overall_source = "mock"
                api_warnings = ["Live API unavailable; deterministic mock data used."]
                txs = transactions_for_mock_address(current, target_address, max_hops)
                fetch = _finalize_candidates(txs)
                partial_data = False
            elif fetch.error and current != target_address:
                api_warnings.extend(fetch.api_warnings)
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
                # The same blockchain transfer can appear when both endpoints
                # are queried. Count the second observation as other_filtered,
                # rather than creating a duplicate graph edge.
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
            # MultiDiGraph preserves every eligible transfer independently.
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

    filtered = (
        totals["below"]
        + totals["unpriced_token"]
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
            + totals["unpriced_token"]
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

    nearest_vasp, path = _find_nearest_vasp(graph, target_address)
    return TraceOutcome(
        graph,
        target_address,
        overall_source,
        nearest_vasp,
        path,
        max_hops,
        reached_hops,
        depth_stop_reason,
        analysis,
        transactions_by_node,
    )

def _find_nearest_vasp(graph: nx.MultiDiGraph, target_address: str) -> Tuple[Optional[str], List[str]]:
    undirected = graph.to_undirected()
    vasp_nodes = [n for n, data in graph.nodes(data=True) if data.get("is_vasp")]
    best_vasp: Optional[str] = None
    best_path: List[str] = []
    for vasp_node in vasp_nodes:
        if not nx.has_path(undirected, target_address, vasp_node): continue
        candidate = nx.shortest_path(undirected, target_address, vasp_node)
        if not best_path or len(candidate) < len(best_path):
            best_path, best_vasp = candidate, vasp_node
    return best_vasp, best_path

# --------------------------------------------------------------------------- #
# Scoring
# --------------------------------------------------------------------------- #
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
    if intermediary_count: notes.append(f"{intermediary_count} intermediary wallet(s) reduce confidence by {intermediary_count * 8}.")
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

# --------------------------------------------------------------------------- #
# Response assembly
# --------------------------------------------------------------------------- #
def build_trace_response(outcome: TraceOutcome, max_hops: int) -> TraceResponse:
    nodes = [NodeModel(
        id=node_id, label="VASP" if data.get("is_vasp") else ("Target Wallet" if data.get("is_target") else "Wallet"),
        is_vasp=bool(data.get("is_vasp")), vasp_name=data.get("vasp_name"), vasp_type=data.get("vasp_type"),
        is_target=bool(data.get("is_target")),
    ) for node_id, data in outcome.graph.nodes(data=True)]
    edges = [EdgeModel(
        **{"from": u, "to": v, **{k: data.get(k) for k in [
            "asset_type", "asset_symbol", "amount", "tx_hash", "timestamp", "block_number", "transaction_type", "token_contract",
            "token_decimals", "token_raw_amount"]}}
    ) for u, v, data in outcome.graph.edges(data=True)]
    confidence, risk, notes = compute_scores(outcome.graph, outcome.target_address, outcome.path, outcome.data_source)
    vasp_meta = lookup_vasp(outcome.vasp_address) if outcome.vasp_address else None
    summary = AttributionSummary(
        target_wallet=outcome.target_address,
        nearest_vasp=vasp_meta["name"] if vasp_meta else None,
        vasp_type=vasp_meta["type"] if vasp_meta else None,
        hop_count=(len(outcome.path) - 1) if outcome.path else None,
        requested_hops=max_hops, reached_hops=outcome.reached_hops, depth_stop_reason=outcome.depth_stop_reason,
        confidence_score=confidence, risk_score=risk, data_source=outcome.data_source,
        path=outcome.path, scoring_notes=notes,
    )
    return TraceResponse(nodes=nodes, edges=edges, summary=summary, analysis=AnalysisModel(**outcome.analysis))

# --------------------------------------------------------------------------- #
# PDF evidence report
# --------------------------------------------------------------------------- #
def generate_pdf_report(response: TraceResponse) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=16*mm, bottomMargin=16*mm, leftMargin=14*mm, rightMargin=14*mm)
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("ReportTitle", parent=styles["Title"], fontSize=18, spaceAfter=4, textColor=colors.black)
    subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontSize=9, textColor=colors.HexColor("#333333"))
    heading_style = ParagraphStyle("SectionHeading", parent=styles["Heading2"], fontSize=12, spaceBefore=12, spaceAfter=5)
    body_style = ParagraphStyle("Body", parent=styles["Normal"], fontSize=8.5, leading=11)
    mono_style = ParagraphStyle("Mono", parent=styles["Normal"], fontSize=7.5, fontName="Courier", leading=9)
    elements: List[Any] = []
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    s = response.summary; a = response.analysis
    elements += [Paragraph("CryptoTrace — Forensic Evidence Report", title_style), Paragraph(f"Generated: {generated_at}", subtitle_style), Spacer(1, 8)]
    summary_rows = [
        ["Target Wallet", s.target_wallet], ["Data Source", s.data_source.upper()],
        ["Nearest VASP", s.nearest_vasp or "None detected within hop limit"], ["VASP Type", s.vasp_type or "N/A"],
        ["Requested Hop Depth", str(s.requested_hops)], ["Reached Hop Depth", str(s.reached_hops)],
        ["Depth Stop Reason", s.depth_stop_reason or "Full requested depth reached"],
        ["Minimum Transfer Threshold", f"{a.minimum_transfer_eth:g} ETH"],
        ["Transactions Examined", str(a.transactions_examined)], ["Transactions Included", str(a.transactions_included)],
        ["Transactions Filtered", str(a.transactions_filtered)], ["Filtered Below Threshold", str(a.filtered_below_eth_threshold)],
        ["Unpriced Token Transactions", str(a.unpriced_token_transactions)], ["Contract Interactions", str(a.contract_interactions)],
        ["Internal ETH Transactions", str(a.internal_eth_transactions)], ["ERC-20 Transactions", str(a.erc20_transactions)],
        ["Partial Data", "Yes" if a.partial_data else "No"],
        ["API Warnings", " | ".join(a.api_warnings) if a.api_warnings else "None"],
        ["Truncation", "Yes" if a.truncated else "No"], ["Truncation Reason", a.truncation_reason or "N/A"],
        ["Confidence Score (heuristic)", f"{s.confidence_score} / 100"], ["Risk Score (heuristic)", f"{s.risk_score} / 100"],
    ]
    elements.append(Paragraph("Attribution & Analysis Summary", heading_style))
    table = Table(summary_rows, colWidths=[55*mm, 120*mm])
    table.setStyle(TableStyle([("GRID",(0,0),(-1,-1),0.4,colors.black),("BACKGROUND",(0,0),(0,-1),colors.HexColor("#EFEFEF")),("FONTSIZE",(0,0),(-1,-1),8),("VALIGN",(0,0),(-1,-1),"MIDDLE"),("LEFTPADDING",(0,0),(-1,-1),5),("TOPPADDING",(0,0),(-1,-1),3),("BOTTOMPADDING",(0,0),(-1,-1),3)]))
    elements.append(table)
    elements.append(Paragraph("Wallet Path", heading_style))
    if s.path:
        for i, addr in enumerate(s.path):
            marker = "TARGET" if i == 0 else ("VASP" if i == len(s.path)-1 else f"HOP {i}")
            elements.append(Paragraph(f"[{marker}] {addr}", mono_style))
    else:
        elements.append(Paragraph("No path to a known VASP found within the requested hop depth.", body_style))
    elements.append(Paragraph("Scoring Rationale", heading_style))
    for note in s.scoring_notes: elements.append(Paragraph(f"• {note}", body_style))
    elements.append(Paragraph("Transaction History", heading_style))
    if response.edges:
        rows = [["From", "To", "Asset / Amount", "Type", "Tx Hash", "Timestamp"]]
        for e in sorted(response.edges, key=lambda x: x.timestamp):
            if e.asset_type == "contract_interaction":
                amount_text = "Contract interaction"
            elif e.asset_symbol == "ETH" or e.asset_type in {"native_eth", "internal_eth"}:
                amount_text = _format_eth_amount(e.amount)
            else:
                amount_text = f"{e.amount:g} {e.asset_symbol or 'TOKEN'}".strip()
            rows.append([_shorten(e.from_), _shorten(e.to), amount_text, e.transaction_type, _shorten(e.tx_hash, 8), e.timestamp[:19].replace("T", " ")])
        tx_table = Table(rows, colWidths=[28*mm,28*mm,38*mm,27*mm,30*mm,38*mm], repeatRows=1)
        tx_table.setStyle(TableStyle([("GRID",(0,0),(-1,-1),0.35,colors.black),("BACKGROUND",(0,0),(-1,0),colors.HexColor("#DDDDDD")),("FONTSIZE",(0,0),(-1,-1),6.2),("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("TOPPADDING",(0,0),(-1,-1),2),("BOTTOMPADDING",(0,0),(-1,-1),2)]))
        elements.append(tx_table)
    else:
        elements.append(Paragraph("No economically eligible transfers were included in this trace.", body_style))
    elements.append(Spacer(1, 10))
    elements.append(Paragraph("Disclaimer", heading_style))
    elements.append(Paragraph(s.disclaimer + " The 0.0005 ETH rule is a per-transfer filter and does not by itself detect transaction splitting. VASP registry records in this prototype are demonstration records unless explicitly marked verified.", body_style))
    doc.build(elements)
    return buffer.getvalue()

# --------------------------------------------------------------------------- #
# FastAPI application
# --------------------------------------------------------------------------- #
app = FastAPI(title="CryptoTrace — VASP Attribution Portal", description="Heuristic Ethereum wallet-to-VASP attribution service (prototype).", version="1.1.0")
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_credentials=True, allow_methods=["GET", "POST"], allow_headers=["*"])

@app.get("/api/health", response_model=HealthResponse)
def health_check() -> HealthResponse:
    return HealthResponse(status="online", etherscan_key_configured=bool(ETHERSCAN_API_KEY), timestamp=datetime.now(timezone.utc).isoformat())

@app.post("/api/trace", response_model=TraceResponse)
def trace_endpoint(request: TraceRequest) -> TraceResponse:
    try:
        return build_trace_response(trace_wallet(request.wallet_address, request.max_hops), request.max_hops)
    except Exception:
        logger.exception("Unexpected error while tracing wallet %s", request.wallet_address)
        raise HTTPException(status_code=500, detail="Internal error while tracing wallet. Please try again.")

@app.get("/api/report/{wallet}")
def report_endpoint(wallet: str, max_hops: int = 2):
    wallet = wallet.strip().lower()
    if not is_valid_eth_address(wallet): raise HTTPException(status_code=400, detail="Invalid Ethereum wallet address.")
    if not (1 <= max_hops <= MAX_HOPS_ALLOWED): raise HTTPException(status_code=400, detail=f"max_hops must be between 1 and {MAX_HOPS_ALLOWED}.")
    try:
        response_data = build_trace_response(trace_wallet(wallet, max_hops), max_hops)
        pdf_bytes = generate_pdf_report(response_data)
    except Exception:
        logger.exception("Unexpected error while generating report for %s", wallet)
        raise HTTPException(status_code=500, detail="Internal error while generating the report.")
    filename = f"cryptotrace_report_{wallet[:10]}.pdf"
    return Response(content=pdf_bytes, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{filename}"'})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
