"""Small, reusable helpers shared across the library."""
from __future__ import annotations

from cryptotrace.config import ETH_ADDRESS_PATTERN


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
