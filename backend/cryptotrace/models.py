"""Public API models and internal tracing data classes."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

import networkx as nx
from pydantic import BaseModel, Field, field_validator

from cryptotrace.config import ETH_ADDRESS_PATTERN, MAX_HOPS_ALLOWED


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


class CaseMetadataModel(BaseModel):
    case_id: str
    created_at: str
    schema_version: str = "1.0"


class VaspProvenanceModel(BaseModel):
    source: str
    source_type: str
    source_url: Optional[str] = None
    verification_status: str
    last_verified: Optional[str] = None
    notes: Optional[str] = None


class ScoreFactorModel(BaseModel):
    key: str
    label: str
    points: int
    explanation: str


class ScoreBreakdownModel(BaseModel):
    score_type: str
    base_score: int
    factors: List[ScoreFactorModel]
    final_score: int


class PatternIndicatorModel(BaseModel):
    key: str
    label: str
    severity: str
    description: str
    node_ids: List[str] = Field(default_factory=list)
    tx_hashes: List[str] = Field(default_factory=list)
    evidence: Dict[str, Any] = Field(default_factory=dict)


class PathHopModel(BaseModel):
    from_: str = Field(..., alias="from")
    to: str
    direction: str
    outgoing_tx_hashes: List[str] = Field(default_factory=list)
    incoming_tx_hashes: List[str] = Field(default_factory=list)



class NodeModel(BaseModel):
    id: str
    label: str
    is_vasp: bool
    vasp_verified: bool = False
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
    explorer_url: Optional[str] = None

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
    vasp_provenance: Optional[VaspProvenanceModel] = None
    hop_count: Optional[int]
    requested_hops: int
    reached_hops: int
    depth_stop_reason: Optional[str] = None
    confidence_score: int
    risk_score: int
    data_source: str
    path: List[str]
    vasp_direction: Optional[str] = None
    path_hops: List[PathHopModel] = Field(default_factory=list)
    scoring_notes: List[str]
    confidence_breakdown: Optional[ScoreBreakdownModel] = None
    risk_breakdown: Optional[ScoreBreakdownModel] = None
    disclaimer: str = (
        "This attribution is derived from heuristic graph analysis of transaction proximity. "
        "It does not constitute proof of wallet ownership, control, or identity, and must not "
        "be treated as a definitive or legal identification."
    )


class TraceResponse(BaseModel):
    case: CaseMetadataModel
    nodes: List[NodeModel]
    edges: List[EdgeModel]
    summary: AttributionSummary
    analysis: AnalysisModel
    patterns: List[PatternIndicatorModel] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: str
    etherscan_key_configured: bool
    timestamp: str


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


@dataclass(frozen=True)
class PathHopEvidence:
    from_address: str
    to_address: str
    direction: str
    outgoing_tx_hashes: List[str] = field(default_factory=list)
    incoming_tx_hashes: List[str] = field(default_factory=list)


@dataclass
class TraceOutcome:
    graph: nx.MultiDiGraph
    target_address: str
    data_source: str
    vasp_address: Optional[str]
    path: List[str]
    vasp_direction: Optional[str]
    path_hops: List[PathHopEvidence]
    requested_hops: int
    reached_hops: int
    depth_stop_reason: Optional[str]
    analysis: Dict[str, Any]
    transactions_by_node: Dict[str, List[TransactionCandidate]] = field(default_factory=dict)
