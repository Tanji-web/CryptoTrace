"""Small, reusable helpers shared across the library."""
from __future__ import annotations

import re
import secrets
from datetime import datetime, timezone

from cryptotrace.config import ETH_ADDRESS_PATTERN

CASE_ID_PATTERN = re.compile(r"^CT-[0-9]{14}-[A-F0-9]{6}$")


def is_valid_eth_address(address: str) -> bool:
    return bool(ETH_ADDRESS_PATTERN.match(address.strip()))


def shorten(value: str, keep: int = 6) -> str:
    if len(value) <= keep * 2 + 3:
        return value
    return f"{value[:keep]}...{value[-4:]}"


def format_eth_amount(value: float) -> str:
    if value == 0:
        return "0 ETH"
    if value >= 1:
        text = f"{value:.2f}"
    elif value >= 0.000001:
        text = f"{value:.6f}"
    else:
        text = f"{value:.8f}"
    return f"{text} ETH"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def generate_case_id(now: datetime | None = None) -> str:
    """Create a compact, human-readable case reference."""
    current = now or datetime.now(timezone.utc)
    timestamp = current.astimezone(timezone.utc).strftime("%Y%m%d%H%M%S")
    return f"CT-{timestamp}-{secrets.token_hex(3).upper()}"


def is_valid_case_id(case_id: str) -> bool:
    return bool(CASE_ID_PATTERN.fullmatch(case_id.strip().upper()))


def transaction_explorer_url(tx_hash: str, source: str) -> str | None:
    if not tx_hash or not tx_hash.startswith("0x"):
        return None
    if not str(source).lower().startswith("live"):
        return None
    return f"https://etherscan.io/tx/{tx_hash}"
