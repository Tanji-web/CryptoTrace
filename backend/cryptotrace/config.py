"""Application configuration and shared runtime settings."""
from __future__ import annotations

import logging
import os
import re

from dotenv import load_dotenv

load_dotenv()

ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY", "").strip()
ETHERSCAN_BASE_URL = "https://api.etherscan.io/v2/api"
ETHERSCAN_TX_URL = "https://etherscan.io/tx/"
ETHERSCAN_TIMEOUT_SECONDS = 8.0
CORS_ORIGINS_RAW = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080")
CORS_ORIGINS = [x.strip() for x in CORS_ORIGINS_RAW.split(",") if x.strip()]

MAX_HOPS_ALLOWED = 3
MAX_GRAPH_NODES = int(os.getenv("MAX_GRAPH_NODES", "100"))
MAX_LIVE_API_CALLS = int(os.getenv("MAX_LIVE_API_CALLS", "30"))
MAX_CANDIDATES_PER_WALLET = int(os.getenv("MAX_CANDIDATES_PER_WALLET", "10"))
MIN_TRANSFER_ETH = 0.0005
MAX_TRANSACTIONS_PER_SOURCE = int(os.getenv("MAX_TRANSACTIONS_PER_SOURCE", "100"))
RATE_LIMIT_REQUESTS_PER_WINDOW = int(os.getenv("RATE_LIMIT_REQUESTS_PER_WINDOW", "30"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
TRACE_CACHE_TTL_SECONDS = int(os.getenv("TRACE_CACHE_TTL_SECONDS", "30"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("cryptotrace")
ETH_ADDRESS_PATTERN = re.compile(r"^0x[a-fA-F0-9]{40}$")
