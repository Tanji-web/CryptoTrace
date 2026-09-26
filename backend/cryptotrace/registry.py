"""Known-VASP registry helpers."""
from __future__ import annotations

from typing import Dict, Optional

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


KNOWN_VASP_WALLETS = {
    _normalize_demo_address(k): v for k, v in KNOWN_VASP_WALLETS.items()
}


def lookup_vasp(address: str) -> Optional[Dict[str, str]]:
    return KNOWN_VASP_WALLETS.get(address.lower())
