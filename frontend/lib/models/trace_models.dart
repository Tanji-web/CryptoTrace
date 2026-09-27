// CryptoTrace frontend data models.


class CaseMetadata {
  final String caseId;
  final String createdAt;
  final String schemaVersion;

  const CaseMetadata({
    required this.caseId,
    required this.createdAt,
    required this.schemaVersion,
  });

  factory CaseMetadata.fromJson(Map<String, dynamic> json) {
    return CaseMetadata(
      caseId: json['case_id'] as String? ?? 'UNKNOWN',
      createdAt: json['created_at'] as String? ?? '',
      schemaVersion: json['schema_version'] as String? ?? '1.0',
    );
  }
}

class GraphNode {
  final String id;
  final String label;
  final bool isVasp;
  final bool vaspVerified;
  final String? vaspName;
  final String? vaspType;
  final bool isTarget;

  GraphNode({
    required this.id,
    required this.label,
    required this.isVasp,
    this.vaspVerified = false,
    required this.isTarget,
    this.vaspName,
    this.vaspType,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Wallet',
      isVasp: json['is_vasp'] as bool? ?? false,
      vaspVerified: json['vasp_verified'] as bool? ?? false,
      isTarget: json['is_target'] as bool? ?? false,
      vaspName: json['vasp_name'] as String?,
      vaspType: json['vasp_type'] as String?,
    );
  }
}

class GraphEdge {
  final String from;
  final String to;
  final String assetType;
  final String? assetSymbol;
  final double amount;
  final String txHash;
  final String timestamp;
  final int? blockNumber;
  final String transactionType;
  final String? tokenContract;
  final int? tokenDecimals;
  final String? tokenRawAmount;
  final String? explorerUrl;

  GraphEdge({
    required this.from,
    required this.to,
    required this.assetType,
    required this.amount,
    required this.txHash,
    required this.timestamp,
    required this.transactionType,
    this.assetSymbol,
    this.blockNumber,
    this.tokenContract,
    this.tokenDecimals,
    this.tokenRawAmount,
    this.explorerUrl,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      assetType: json['asset_type'] as String? ?? 'unknown',
      assetSymbol: json['asset_symbol'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      txHash: json['tx_hash'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      blockNumber: json['block_number'] as int?,
      transactionType: json['transaction_type'] as String? ?? 'unknown',
      tokenContract: json['token_contract'] as String?,
      tokenDecimals: json['token_decimals'] as int?,
      tokenRawAmount: json['token_raw_amount'] as String?,
      explorerUrl: json['explorer_url'] as String?,
    );
  }
}

class VaspProvenance {
  final String source;
  final String sourceType;
  final String? sourceUrl;
  final String verificationStatus;
  final String? lastVerified;
  final String? notes;

  const VaspProvenance({
    required this.source,
    required this.sourceType,
    required this.verificationStatus,
    this.sourceUrl,
    this.lastVerified,
    this.notes,
  });

  factory VaspProvenance.fromJson(Map<String, dynamic> json) {
    return VaspProvenance(
      source: json['source'] as String? ?? 'unknown',
      sourceType: json['source_type'] as String? ?? 'unknown',
      sourceUrl: json['source_url'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'unknown',
      lastVerified: json['last_verified'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class AnalysisSummary {
  final double minimumTransferEth;
  final int transactionsExamined;
  final int transactionsIncluded;
  final int transactionsFiltered;
  final int filteredBelowEthThreshold;
  final int unpricedTokenTransactions;
  final int filteredCandidateLimit;
  final int filteredNonEconomicContractCalls;
  final int filteredOther;
  final int contractInteractions;
  final int internalEthTransactions;
  final int erc20Transactions;
  final Map<String, dynamic> limits;
  final bool truncated;
  final String? truncationReason;
  final bool partialData;
  final List<String> apiWarnings;

  AnalysisSummary({
    required this.minimumTransferEth,
    required this.transactionsExamined,
    required this.transactionsIncluded,
    required this.transactionsFiltered,
    required this.filteredBelowEthThreshold,
    required this.unpricedTokenTransactions,
    required this.filteredCandidateLimit,
    required this.filteredNonEconomicContractCalls,
    required this.filteredOther,
    required this.contractInteractions,
    required this.internalEthTransactions,
    required this.erc20Transactions,
    required this.limits,
    required this.truncated,
    this.truncationReason,
    this.partialData = false,
    this.apiWarnings = const [],
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) => AnalysisSummary(
    minimumTransferEth: (json['minimum_transfer_eth'] as num?)?.toDouble() ?? 0.0005,
    transactionsExamined: json['transactions_examined'] as int? ?? 0,
    transactionsIncluded: json['transactions_included'] as int? ?? 0,
    transactionsFiltered: json['transactions_filtered'] as int? ?? 0,
    filteredBelowEthThreshold: json['filtered_below_eth_threshold'] as int? ?? 0,
    unpricedTokenTransactions: json['unpriced_token_transactions'] as int? ?? 0,
    filteredCandidateLimit: json['filtered_candidate_limit'] as int? ?? 0,
    filteredNonEconomicContractCalls: json['filtered_non_economic_contract_calls'] as int? ?? 0,
    filteredOther: json['filtered_other'] as int? ?? 0,
    contractInteractions: json['contract_interactions'] as int? ?? 0,
    internalEthTransactions: json['internal_eth_transactions'] as int? ?? 0,
    erc20Transactions: json['erc20_transactions'] as int? ?? 0,
    limits: (json['limits'] as Map?)?.cast<String, dynamic>() ?? const {},
    truncated: json['truncated'] as bool? ?? false,
    truncationReason: json['truncation_reason'] as String?,
    partialData: json['partial_data'] as bool? ?? false,
    apiWarnings: (json['api_warnings'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
  );
}

class ScoreFactor {
  final String key;
  final String label;
  final int points;
  final String explanation;

  const ScoreFactor({
    required this.key,
    required this.label,
    required this.points,
    required this.explanation,
  });

  factory ScoreFactor.fromJson(Map<String, dynamic> json) {
    return ScoreFactor(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      points: json['points'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class ScoreBreakdown {
  final String scoreType;
  final int baseScore;
  final List<ScoreFactor> factors;
  final int finalScore;

  const ScoreBreakdown({
    required this.scoreType,
    required this.baseScore,
    required this.factors,
    required this.finalScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      scoreType: json['score_type'] as String? ?? '',
      baseScore: json['base_score'] as int? ?? 0,
      factors: (json['factors'] as List<dynamic>? ?? const [])
          .map((e) => ScoreFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
      finalScore: json['final_score'] as int? ?? 0,
    );
  }
}

class PatternIndicator {
  final String key;
  final String label;
  final String severity;
  final String description;
  final List<String> nodeIds;
  final List<String> txHashes;
  final Map<String, dynamic> evidence;

  const PatternIndicator({
    required this.key,
    required this.label,
    required this.severity,
    required this.description,
    required this.nodeIds,
    required this.txHashes,
    required this.evidence,
  });

  factory PatternIndicator.fromJson(Map<String, dynamic> json) {
    return PatternIndicator(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      severity: json['severity'] as String? ?? 'informational',
      description: json['description'] as String? ?? '',
      nodeIds: (json['node_ids'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      txHashes: (json['tx_hashes'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      evidence: (json['evidence'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class PathHop {
  final String from;
  final String to;
  final String direction;
  final List<String> outgoingTxHashes;
  final List<String> incomingTxHashes;

  const PathHop({
    required this.from,
    required this.to,
    required this.direction,
    required this.outgoingTxHashes,
    required this.incomingTxHashes,
  });

  List<String> get transactionHashes => <String>{
        ...outgoingTxHashes,
        ...incomingTxHashes,
      }.toList();

  factory PathHop.fromJson(Map<String, dynamic> json) {
    return PathHop(
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      direction: json['direction'] as String? ?? 'unknown',
      outgoingTxHashes: (json['outgoing_tx_hashes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      incomingTxHashes: (json['incoming_tx_hashes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AttributionSummary {
  final String targetWallet;
  final String? nearestVasp;
  final String? vaspType;
  final VaspProvenance? vaspProvenance;
  final int? hopCount;
  final int requestedHops;
  final int reachedHops;
  final String? depthStopReason;
  final int confidenceScore;
  final int riskScore;
  final String dataSource;
  final List<String> path;
  final String? vaspDirection;
  final List<PathHop> pathHops;
  final List<String> scoringNotes;
  final ScoreBreakdown? confidenceBreakdown;
  final ScoreBreakdown? riskBreakdown;
  final String disclaimer;

  AttributionSummary({
    required this.targetWallet,
    required this.confidenceScore,
    required this.riskScore,
    required this.dataSource,
    required this.path,
    required this.scoringNotes,
    this.vaspDirection,
    this.pathHops = const [],
    required this.disclaimer,
    this.confidenceBreakdown,
    this.riskBreakdown,
    this.nearestVasp,
    this.vaspType,
    this.vaspProvenance,
    this.hopCount,
    this.requestedHops = 2,
    this.reachedHops = 0,
    this.depthStopReason,
  });

  factory AttributionSummary.fromJson(Map<String, dynamic> json) {
    return AttributionSummary(
      targetWallet: json['target_wallet'] as String,
      nearestVasp: json['nearest_vasp'] as String?,
      vaspType: json['vasp_type'] as String?,
      vaspProvenance: json['vasp_provenance'] is Map<String, dynamic>
          ? VaspProvenance.fromJson(json['vasp_provenance'] as Map<String, dynamic>)
          : null,
      hopCount: json['hop_count'] as int?,
      requestedHops: json['requested_hops'] as int? ?? 2,
      reachedHops: json['reached_hops'] as int? ?? (json['hop_count'] as int? ?? 0),
      depthStopReason: json['depth_stop_reason'] as String?,
      confidenceScore: json['confidence_score'] as int? ?? 0,
      riskScore: json['risk_score'] as int? ?? 0,
      dataSource: json['data_source'] as String? ?? 'mock',
      path: (json['path'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      scoringNotes: (json['scoring_notes'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      confidenceBreakdown: json['confidence_breakdown'] is Map<String, dynamic>
          ? ScoreBreakdown.fromJson(json['confidence_breakdown'] as Map<String, dynamic>)
          : null,
      riskBreakdown: json['risk_breakdown'] is Map<String, dynamic>
          ? ScoreBreakdown.fromJson(json['risk_breakdown'] as Map<String, dynamic>)
          : null,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class TraceResult {
  final CaseMetadata caseMetadata;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final AttributionSummary summary;
  final AnalysisSummary analysis;
  final List<PatternIndicator> patterns;

  TraceResult({
    required this.caseMetadata,
    required this.nodes,
    required this.edges,
    required this.summary,
    required this.analysis,
    required this.patterns,
  });

  factory TraceResult.fromJson(Map<String, dynamic> json) {
    final caseJson = json['case'];
    return TraceResult(
      caseMetadata: caseJson is Map<String, dynamic>
          ? CaseMetadata.fromJson(caseJson)
          : const CaseMetadata(caseId: 'UNKNOWN', createdAt: '', schemaVersion: '1.0'),
      nodes: (json['nodes'] as List<dynamic>).map((e) => GraphNode.fromJson(e as Map<String, dynamic>)).toList(),
      edges: (json['edges'] as List<dynamic>).map((e) => GraphEdge.fromJson(e as Map<String, dynamic>)).toList(),
      summary: AttributionSummary.fromJson(json['summary'] as Map<String, dynamic>),
      analysis: AnalysisSummary.fromJson(json['analysis'] as Map<String, dynamic>? ?? const {}),
      patterns: (json['patterns'] as List<dynamic>? ?? const [])
          .map((e) => PatternIndicator.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
