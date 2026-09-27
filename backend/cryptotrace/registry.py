"""Known-VASP registry helpers."""
from __future__ import annotations

from typing import Dict, Optional

# These are deliberately demo records. They must not be presented as verified
# production exchange addresses without an externally sourced intelligence feed.
#
# The provenance fields describe where the demo record points for public address
# evidence; they do NOT prove ownership, control, or legal VASP identity.
_RAW_VASP_WALLETS: Dict[str, Dict[str, str]] = {
    "0x28c6c06298d514db089934071355e5743bf21d60": {
        "name": "Binance",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "source_type": "public_explorer",
        "source_url": "https://etherscan.io/address/0x28c6c06298d514db089934071355e5743bf21d60",
        "verification_status": "demo",
        "verified": "false",
        "last_verified": "",
        "notes": "Demo registry record. The explorer link provides public address provenance only; it does not establish Binance ownership or control of this address.",
    },
    "0x503209a779226e6392913734c7601313380f7192": {
        "name": "Coinbase",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "source_type": "public_explorer",
        "source_url": "https://etherscan.io/address/0x503209a779226e6392913734c7601313380f7192",
        "verification_status": "demo",
        "verified": "false",
        "last_verified": "",
        "notes": "Demo registry record. The explorer link provides public address provenance only; it does not establish Coinbase ownership or control of this address.",
    },
    "0x2910543af39aba0cd09d90708cc63a1196b9e498": {
        "name": "Kraken",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "source_type": "public_explorer",
        "source_url": "https://etherscan.io/address/0x2910543af39aba0cd09d90708cc63a1196b9e498",
        "verification_status": "demo",
        "verified": "false",
        "last_verified": "",
        "notes": "Demo registry record. The explorer link provides public address provenance only; it does not establish Kraken ownership or control of this address.",
    },
    "0x27029817b2f2a12111e9f1c4b0a6a8f673f84824": {
        "name": "WazirX",
        "type": "Exchange",
        "source": "manual_vasp_registry",
        "source_type": "public_explorer",
        "source_url": "https://etherscan.io/address/0x27029817b2f2a12111e9f1c4b0a6a8f673f84824",
        "verification_status": "demo",
        "verified": "false",
        "last_verified": "",
        "notes": "Demo registry record. The explorer link provides public address provenance only; it does not establish WazirX ownership or control of this address.",
    },
}


KNOWN_VASP_WALLETS = dict(_RAW_VASP_WALLETS)


def lookup_vasp(address: str) -> Optional[Dict[str, str]]:
    return KNOWN_VASP_WALLETS.get(address.lower())
