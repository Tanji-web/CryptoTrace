"""Etherscan ingestion, parsing, classification, and candidate filtering."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import httpx

from cryptotrace.config import ETHERSCAN_API_KEY, ETHERSCAN_BASE_URL, ETHERSCAN_TIMEOUT_SECONDS, MAX_CANDIDATES_PER_WALLET, MAX_LIVE_API_CALLS, MAX_TRANSACTIONS_PER_SOURCE
from cryptotrace.models import FetchResult, TransactionCandidate
from cryptotrace.registry import lookup_vasp
from cryptotrace.utils import is_valid_eth_address
from cryptotrace.config import MIN_TRANSFER_ETH


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


def finalize_candidates(candidates: List[TransactionCandidate]) -> FetchResult:
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


def fetch_live_for_address(address: str, api_calls: List[int]) -> FetchResult:
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

    finalized = finalize_candidates(all_candidates)
    warnings = list(dict.fromkeys(errors))
    partial_data = source_failures > 0
    all_sources_failed = source_failures == len(source_names)
    finalized.source = "live"
    finalized.error = "; ".join(warnings) if all_sources_failed else None
    finalized.partial_data = partial_data
    finalized.api_warnings = warnings
    return finalized
