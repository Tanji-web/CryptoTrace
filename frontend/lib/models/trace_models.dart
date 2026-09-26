// CryptoTrace frontend data models.

class GraphNode {
  final String id;
  final String label;
  final bool isVasp;
  final String? vaspName;
  final String? vaspType;
  final bool isTarget;

  GraphNode({
    required this.id,
    required this.label,
    required this.isVasp,
    required this.isTarget,
    this.vaspName,
    this.vaspType,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Wallet',
      isVasp: json['is_vasp'] as bool? ?? false,
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

class AttributionSummary {
  final String targetWallet;
  final String? nearestVasp;
  final String? vaspType;
  final int? hopCount;
  final int requestedHops;
  final int reachedHops;
  final String? depthStopReason;
  final int confidenceScore;
  final int riskScore;
  final String dataSource;
  final List<String> path;
  final List<String> scoringNotes;
  final String disclaimer;

  AttributionSummary({
    required this.targetWallet,
    required this.confidenceScore,
    required this.riskScore,
    required this.dataSource,
    required this.path,
    required this.scoringNotes,
    required this.disclaimer,
    this.nearestVasp,
    this.vaspType,
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
      hopCount: json['hop_count'] as int?,
      requestedHops: json['requested_hops'] as int? ?? 2,
      reachedHops: json['reached_hops'] as int? ?? (json['hop_count'] as int? ?? 0),
      depthStopReason: json['depth_stop_reason'] as String?,
      confidenceScore: json['confidence_score'] as int? ?? 0,
      riskScore: json['risk_score'] as int? ?? 0,
      dataSource: json['data_source'] as String? ?? 'mock',
      path: (json['path'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      scoringNotes: (json['scoring_notes'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class TraceResult {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final AttributionSummary summary;
  final AnalysisSummary analysis;

  TraceResult({required this.nodes, required this.edges, required this.summary, required this.analysis});

  factory TraceResult.fromJson(Map<String, dynamic> json) {
    return TraceResult(
      nodes: (json['nodes'] as List<dynamic>).map((e) => GraphNode.fromJson(e as Map<String, dynamic>)).toList(),
      edges: (json['edges'] as List<dynamic>).map((e) => GraphEdge.fromJson(e as Map<String, dynamic>)).toList(),
      summary: AttributionSummary.fromJson(json['summary'] as Map<String, dynamic>),
      analysis: AnalysisSummary.fromJson(json['analysis'] as Map<String, dynamic>? ?? const {}),
    );
  }
}
