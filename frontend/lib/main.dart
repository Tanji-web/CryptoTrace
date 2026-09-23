// CryptoTrace — VASP Attribution Portal
//
// Flutter Web/Desktop frontend for the CryptoTrace backend. Provides wallet
// input, hop-depth selection, an interactive transaction graph, an
// attribution summary panel, a transaction path timeline, and forensic PDF
// export.
//
// State management: plain StatefulWidget + setState is used throughout.
// The application is small and single-screen, so introducing a dedicated
// state-management framework (Provider/Bloc/Riverpod) would add ceremony
// without a corresponding benefit here.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CryptoTraceApp());
}

// --------------------------------------------------------------------------- //
// Design tokens
// --------------------------------------------------------------------------- //

class AppColors {
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF4F46E5);
  static const vasp = Color(0xFF059669);
  static const targetAmber = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const wallet = Color(0xFF3B82F6);
}

// --------------------------------------------------------------------------- //
// App shell
// --------------------------------------------------------------------------- //

class CryptoTraceApp extends StatelessWidget {
  const CryptoTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptoTrace — VASP Attribution Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        dividerColor: AppColors.border,
      ),
      home: const CryptoTraceHomePage(),
    );
  }
}

// --------------------------------------------------------------------------- //
// Data models
// --------------------------------------------------------------------------- //

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

// --------------------------------------------------------------------------- //
// API client
// --------------------------------------------------------------------------- //

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  // Adjust for your deployment. Kept as a plain constant since this is a
  // single-file prototype frontend.
  static const String baseUrl = 'http://localhost:8000';

  static Future<TraceResult> traceWallet(String walletAddress, int maxHops) async {
    final uri = Uri.parse('$baseUrl/api/trace');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'wallet_address': walletAddress, 'max_hops': maxHops}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Could not reach the CryptoTrace backend. Is it running?');
    }

    if (response.statusCode == 200) {
      return TraceResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    if (response.statusCode == 422) {
      throw ApiException('Please enter a valid Ethereum wallet address.');
    }

    throw ApiException('The backend returned an unexpected error (HTTP ${response.statusCode}).');
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Uri reportUri(String wallet, int maxHops) {
    return Uri.parse('$baseUrl/api/report/$wallet?max_hops=$maxHops');
  }
}

// --------------------------------------------------------------------------- //
// Home page
// --------------------------------------------------------------------------- //

class CryptoTraceHomePage extends StatefulWidget {
  const CryptoTraceHomePage({super.key});

  @override
  State<CryptoTraceHomePage> createState() => _CryptoTraceHomePageState();
}

class _CryptoTraceHomePageState extends State<CryptoTraceHomePage> {
  final TextEditingController _addressController = TextEditingController();
  int _hopDepth = 2;
  bool _isLoading = false;
  String? _errorMessage;
  TraceResult? _result;
  String? _selectedNodeId;
  bool _backendOnline = false;
  bool _isExportingPdf = false;
  Timer? _healthTimer;

  static final RegExp _addressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

  @override
  void initState() {
    super.initState();
    _pollHealth();
    // Re-check periodically so a backend restart, a dropped connection, or a
    // transient CORS/network hiccup self-corrects without requiring the user
    // to reload the whole app.
    _healthTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollHealth());
  }

  Future<void> _pollHealth() async {
    final online = await ApiClient.checkHealth();
    if (mounted) setState(() => _backendOnline = online);
  }

  String? _validateAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Please enter a wallet address.';
    if (!_addressPattern.hasMatch(trimmed)) {
      return 'Invalid Ethereum address. Expected format: 0x followed by 40 hex characters.';
    }
    return null;
  }

  Future<void> _runTrace() async {
    final validationError = _validateAddress(_addressController.text);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedNodeId = null;
    });

    try {
      final result = await ApiClient.traceWallet(_addressController.text.trim().toLowerCase(), _hopDepth);
      setState(() {
        _result = result;
        _isLoading = false;
        _selectedNodeId = result.summary.targetWallet;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'An unexpected error occurred while tracing the wallet.';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    setState(() => _isExportingPdf = true);

    final uri = ApiClient.reportUri(_result!.summary.targetWallet, _hopDepth);
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) {
        throw Exception('launch failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate or open the evidence PDF. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HeaderBar(backendOnline: _backendOnline, onStatusTap: _pollHealth),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _InputPanel(
                            controller: _addressController,
                            hopDepth: _hopDepth,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                            onTrace: _runTrace,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _GraphSection(
                            result: _result,
                            isLoading: _isLoading,
                            selectedNodeId: _selectedNodeId,
                            onNodeSelected: (id) => setState(() => _selectedNodeId = id),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 340,
                          child: _AttributionPanel(
                            result: _result,
                            isExportingPdf: _isExportingPdf,
                            onExportPdf: _exportPdf,
                          ),
                        ),
                      ],
                    );
                  }
                  // Narrow / mobile layout: stack panels vertically.
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _InputPanel(
                          controller: _addressController,
                          hopDepth: _hopDepth,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                          onTrace: _runTrace,
                        ),
                        SizedBox(
                          height: 420,
                          child: _GraphSection(
                            result: _result,
                            isLoading: _isLoading,
                            selectedNodeId: _selectedNodeId,
                            onNodeSelected: (id) => setState(() => _selectedNodeId = id),
                          ),
                        ),
                        _AttributionPanel(
                          result: _result,
                          isExportingPdf: _isExportingPdf,
                          onExportPdf: _exportPdf,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Header
// --------------------------------------------------------------------------- //

class _HeaderBar extends StatelessWidget {
  final bool backendOnline;
  final VoidCallback onStatusTap;
  const _HeaderBar({required this.backendOnline, required this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'CryptoTrace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          const Text(
            '— VASP Attribution Portal',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Tooltip(
            message: 'Tap to re-check backend connection',
            child: GestureDetector(
              onTap: onStatusTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: backendOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: backendOnline ? AppColors.vasp : AppColors.danger, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backendOnline ? AppColors.vasp : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      backendOnline ? 'Status: Online' : 'Status: Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: backendOnline ? AppColors.vasp : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Input panel
// --------------------------------------------------------------------------- //

class _InputPanel extends StatelessWidget {
  final TextEditingController controller;
  final int hopDepth;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<int> onHopDepthChanged;
  final VoidCallback onTrace;

  const _InputPanel({
    required this.controller,
    required this.hopDepth,
    required this.isLoading,
    required this.errorMessage,
    required this.onHopDepthChanged,
    required this.onTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: !isLoading,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '0x...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Hop Depth', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3].map((depth) {
              final selected = depth == hopDepth;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: isLoading ? null : () => onHopDepthChanged(depth),
                  child: Container(
                    width: 44,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      '$depth',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minimum transfer value',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('0.0005 ETH per transfer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTrace,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Trace Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Attribution results are heuristic. Graph proximity to a known VASP '
              'does not confirm wallet ownership or identity.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Graph section (canvas + legend)
// --------------------------------------------------------------------------- //

class _GraphSection extends StatelessWidget {
  final TraceResult? result;
  final bool isLoading;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;

  const _GraphSection({
    required this.result,
    required this.isLoading,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : result == null
                    ? const Center(
                        child: Text(
                          'Enter a wallet address and click "Trace Wallet" to build the graph.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _TransactionGraph(
                        result: result!,
                        selectedNodeId: selectedNodeId,
                        onNodeSelected: onNodeSelected,
                      ),
          ),
          if (result != null)
            Positioned(
              left: 16,
              bottom: 16,
              child: _GraphLegend(),
            ),
        ],
      ),
    );
  }
}

class _GraphLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(AppColors.targetAmber, 'Target wallet'),
          item(AppColors.wallet, 'Wallet'),
          item(AppColors.vasp, 'Known VASP'),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Transaction graph rendering
// --------------------------------------------------------------------------- //

class _TransactionGraph extends StatefulWidget {
  final TraceResult result;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;

  const _TransactionGraph({
    required this.result,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  @override
  State<_TransactionGraph> createState() => _TransactionGraphState();
}

class _TransactionGraphState extends State<_TransactionGraph> {
  int _estimateMaxLevel(TraceResult result) {
    final target = result.summary.targetWallet;
    final adjacency = <String, Set<String>>{for (final n in result.nodes) n.id: <String>{}};
    for (final e in result.edges) {
      adjacency[e.from]?.add(e.to);
      adjacency[e.to]?.add(e.from);
    }
    final levels = <String, int>{target: 0};
    final queue = Queue<String>()..add(target);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in adjacency[current] ?? <String>{}) {
        if (!levels.containsKey(neighbor)) {
          levels[neighbor] = levels[current]! + 1;
          queue.add(neighbor);
        }
      }
    }
    return levels.values.isEmpty ? 0 : levels.values.reduce((a, b) => a > b ? a : b);
  }

  static const double nodeRadius = 26;

  Map<String, Offset> _computeLayout(Size availableSize) {
    final nodes = widget.result.nodes;
    final edges = widget.result.edges;
    final target = widget.result.summary.targetWallet;

    final adjacency = <String, Set<String>>{for (final n in nodes) n.id: <String>{}};
    for (final e in edges) {
      adjacency[e.from]?.add(e.to);
      adjacency[e.to]?.add(e.from);
    }

    final levels = <String, int>{};
    if (nodes.any((n) => n.id == target)) {
      levels[target] = 0;
      final queue = Queue<String>()..add(target);
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        for (final neighbor in adjacency[current] ?? <String>{}) {
          if (!levels.containsKey(neighbor)) {
            levels[neighbor] = levels[current]! + 1;
            queue.add(neighbor);
          }
        }
      }
    }

    var maxLevel = levels.values.isEmpty ? 0 : levels.values.reduce((a, b) => a > b ? a : b);
    for (final n in nodes) {
      levels.putIfAbsent(n.id, () => ++maxLevel);
    }

    final byLevel = <int, List<String>>{};
    for (final entry in levels.entries) {
      byLevel.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final maxNodesInLevel = byLevel.values.fold<int>(1, (m, ids) => ids.length > m ? ids.length : m);
    final dynamicRowSpacing = (availableSize.height / (maxNodesInLevel + 1)).clamp(78.0, 150.0);
    final dynamicColumnSpacing = maxNodesInLevel >= 5 ? 260.0 : 230.0;

    final positions = <String, Offset>{};
    final sortedLevels = byLevel.keys.toList()..sort();
    for (final level in sortedLevels) {
      final ids = byLevel[level]!..sort();
      final columnHeight = ids.length * dynamicRowSpacing;
      final startY = (availableSize.height - columnHeight) / 2 + dynamicRowSpacing / 2;
      for (var i = 0; i < ids.length; i++) {
        positions[ids[i]] = Offset(
          90 + level * dynamicColumnSpacing,
          (startY <= 50 ? 50 : startY) + i * dynamicRowSpacing,
        );
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.result.nodes;
    final edges = widget.result.edges;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLevel = widget.result.nodes.isEmpty
            ? 0
            : _estimateMaxLevel(widget.result);
        final canvasWidth = (constraints.maxWidth > 0 ? constraints.maxWidth : 800)
            .clamp(900, 900 + maxLevel * 230);
        final canvasHeight = (constraints.maxHeight > 0 ? constraints.maxHeight : 600)
            .clamp(620, 1100);
        final canvasSize = Size(canvasWidth.toDouble(), canvasHeight.toDouble());
        final positions = _computeLayout(canvasSize);

        return InteractiveViewer(
          minScale: 0.4,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(200),
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              children: [
                CustomPaint(
                  size: canvasSize,
                  painter: _EdgePainter(edges: edges, positions: positions),
                ),
                for (final node in nodes)
                  if (positions.containsKey(node.id))
                    Positioned(
                      left: positions[node.id]!.dx - nodeRadius,
                      top: positions[node.id]!.dy - nodeRadius,
                      child: _GraphNodeWidget(
                        node: node,
                        radius: nodeRadius,
                        isSelected: node.id == widget.selectedNodeId,
                        onTap: () => _showNodeDetails(context, node),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNodeDetails(BuildContext context, GraphNode node) {
    widget.onNodeSelected(node.id);
    final relatedEdges = widget.result.edges.where((e) => e.from == node.id || e.to == node.id).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.isVasp ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined,
                    color: node.isVasp ? AppColors.vasp : (node.isTarget ? AppColors.targetAmber : AppColors.wallet),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.isTarget ? 'Target Wallet' : (node.vaspName ?? 'Wallet'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(node.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              if (node.isVasp) ...[
                const SizedBox(height: 4),
                Text('Type: ${node.vaspType ?? "Unknown"} (VASP)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
              const Divider(height: 24),
              Text('Transactions (${relatedEdges.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: relatedEdges.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final e = relatedEdges[index];
                    final direction = e.from == node.id ? 'Sent to' : 'Received from';
                    final counterparty = e.from == node.id ? e.to : e.from;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$direction ${_shorten(counterparty)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_edgeLabel(e), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        Text('${e.transactionType} · ${e.timestamp}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Tx: ${_shorten(e.txHash, keep: 10)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _shorten(String value, {int keep = 6}) {
  if (value.length <= keep * 2 + 3) return value;
  return '${value.substring(0, keep)}...${value.substring(value.length - 4)}';
}

class _GraphNodeWidget extends StatelessWidget {
  final GraphNode node;
  final double radius;
  final bool isSelected;
  final VoidCallback onTap;

  const _GraphNodeWidget({
    required this.node,
    required this.radius,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = node.isVasp
        ? AppColors.vasp.withValues(alpha: 0.12)
        : node.isTarget
            ? AppColors.targetAmber.withValues(alpha: 0.15)
            : AppColors.wallet.withValues(alpha: 0.10);
    final Color borderColor = node.isVasp ? AppColors.vasp : (node.isTarget ? AppColors.targetAmber : AppColors.wallet);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
              boxShadow: isSelected
                  ? [BoxShadow(color: borderColor.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)]
                  : [const BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Icon(
              node.isVasp ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined,
              size: 20,
              color: borderColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
            child: Text(
              node.isVasp ? (node.vaspName ?? 'VASP') : _shorten(node.id, keep: 5),
              style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatEth(double value) {
  if (value == 0) return '0 ETH';
  if (value >= 1) return '${value.toStringAsFixed(2)} ETH';
  if (value >= 0.000001) return '${value.toStringAsFixed(6)} ETH';
  return '${value.toStringAsFixed(8)} ETH';
}

String _edgeLabel(GraphEdge edge) {
  if (edge.assetType == 'contract_interaction') return 'Contract interaction';
  final amount = edge.assetSymbol == 'ETH' || edge.assetType == 'native_eth' || edge.assetType == 'internal_eth'
      ? _formatEth(edge.amount)
      : '${edge.amount.toStringAsFixed(edge.amount >= 100 ? 0 : 4)} ${edge.assetSymbol ?? 'TOKEN'}';
  return amount;
}

class _EdgePainter extends CustomPainter {
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;

  _EdgePainter({required this.edges, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pairCounts = <String, int>{};
    final pairSeen = <String, int>{};

    for (final edge in edges) {
      final pair = '${edge.from}|${edge.to}';
      pairCounts[pair] = (pairCounts[pair] ?? 0) + 1;
    }

    for (final edge in edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final pair = '${edge.from}|${edge.to}';
      final index = pairSeen[pair] ?? 0;
      pairSeen[pair] = index + 1;
      final count = pairCounts[pair] ?? 1;

      final direction = to - from;
      final length = direction.distance;
      if (length == 0) continue;
      final unit = direction / length;
      final normal = Offset(-unit.dy, unit.dx);
      final offset = count == 1 ? 0.0 : (index - (count - 1) / 2) * 14.0;
      final curveFrom = from + normal * offset;
      final curveTo = to + normal * offset;

      final path = Path()
        ..moveTo(curveFrom.dx, curveFrom.dy)
        ..quadraticBezierTo(
          (curveFrom.dx + curveTo.dx) / 2 + normal.dx * offset,
          (curveFrom.dy + curveTo.dy) / 2 + normal.dy * offset,
          curveTo.dx,
          curveTo.dy,
        );
      canvas.drawPath(path, linePaint);

      final arrowTip = curveTo - unit * 30;
      _drawArrowhead(canvas, arrowTip - unit * 18, arrowTip, linePaint.color);

      final midpoint = Offset(
        (curveFrom.dx + curveTo.dx) / 2 + normal.dx * offset,
        (curveFrom.dy + curveTo.dy) / 2 + normal.dy * offset,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: _edgeLabel(edge),
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, backgroundColor: AppColors.background),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 180);
      textPainter.paint(canvas, midpoint - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Color color) {
    const arrowSize = 6.0;
    final direction = (to - from);
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    // Stop the arrowhead short of the node circle radius.
    final tip = to - unit * 30;
    final normal = Offset(-unit.dy, unit.dx);
    final p1 = tip - unit * arrowSize + normal * (arrowSize / 2);
    final p2 = tip - unit * arrowSize - normal * (arrowSize / 2);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    return oldDelegate.edges != edges || oldDelegate.positions != positions;
  }
}

// --------------------------------------------------------------------------- //
// Attribution panel
// --------------------------------------------------------------------------- //

class _AttributionPanel extends StatelessWidget {
  final TraceResult? result;
  final bool isExportingPdf;
  final VoidCallback onExportPdf;

  const _AttributionPanel({
    required this.result,
    required this.isExportingPdf,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attribution & Evidence', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            if (result == null)
              const Text(
                'Run a trace to see attribution results here.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else ...[
              _MetricCard(
                title: 'Target Address',
                value: _shorten(result!.summary.targetWallet, keep: 8),
                fullValue: result!.summary.targetWallet,
              ),
              _MetricCard(
                title: 'Nearest VASP',
                value: result!.summary.nearestVasp ?? 'None detected',
                accentColor: result!.summary.nearestVasp != null ? AppColors.vasp : null,
              ),
              _MetricCard(
                title: 'Hop Depth',
                value: 'Requested ${result!.summary.requestedHops} · Reached ${result!.summary.reachedHops}',
                accentColor: result!.summary.reachedHops == result!.summary.requestedHops ? AppColors.vasp : AppColors.targetAmber,
              ),
              _MetricCard(
                title: 'Minimum Transfer Value',
                value: '${result!.analysis.minimumTransferEth.toStringAsFixed(4)} ETH',
              ),
              _MetricCard(
                title: 'Attribution Confidence',
                value: '${result!.summary.confidenceScore} / 100',
                progressValue: result!.summary.confidenceScore / 100,
                accentColor: AppColors.primary,
              ),
              _MetricCard(
                title: 'Risk Score',
                value: '${result!.summary.riskScore} / 100',
                progressValue: result!.summary.riskScore / 100,
                accentColor: result!.summary.riskScore >= 60 ? AppColors.danger : AppColors.targetAmber,
              ),
              _MetricCard(
                title: 'Data Source',
                value: result!.summary.dataSource.toUpperCase(),
                accentColor: result!.summary.dataSource.startsWith('live') ? AppColors.vasp : AppColors.targetAmber,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _AnalysisSummaryCard(result: result!),
              const SizedBox(height: 12),
              const Text('Transaction Path', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              _TransactionPathTimeline(result: result!),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isExportingPdf ? null : onExportPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isExportingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Export Forensic Evidence PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  result!.summary.disclaimer,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? fullValue;
  final Color? accentColor;
  final double? progressValue;

  const _MetricCard({
    required this.title,
    required this.value,
    this.fullValue,
    this.accentColor,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Tooltip(
            message: fullValue ?? '',
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accentColor ?? AppColors.textPrimary,
                fontFamily: fullValue != null ? 'monospace' : null,
              ),
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: accentColor ?? AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisSummaryCard extends StatelessWidget {
  final TraceResult result;
  const _AnalysisSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final a = result.analysis;
    final stop = result.summary.depthStopReason;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Trace Analysis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 8),
        _analysisRow('Examined', '${a.transactionsExamined}'),
        _analysisRow('Included', '${a.transactionsIncluded}'),
        _analysisRow('Filtered', '${a.transactionsFiltered}'),
        _analysisRow('Below 0.0005 ETH', '${a.filteredBelowEthThreshold}'),
        _analysisRow('Unpriced tokens', '${a.unpricedTokenTransactions}'),
        _analysisRow('Candidate limit', '${a.filteredCandidateLimit}'),
        _analysisRow('Contract interactions', '${a.contractInteractions}'),
        _analysisRow('Non-economic contract calls', '${a.filteredNonEconomicContractCalls}'),
        _analysisRow('Other filtered', '${a.filteredOther}'),
        _analysisRow('Internal ETH transfers', '${a.internalEthTransactions}'),
        _analysisRow('ERC-20 transfers', '${a.erc20Transactions}'),
        if (a.partialData) _analysisRow('Partial live data', 'Yes', danger: true),
        if (a.truncated) _analysisRow('Truncated', a.truncationReason ?? 'yes', danger: true),
        if (stop != null && result.summary.reachedHops < result.summary.requestedHops)
          _analysisRow('Depth stop', stop.replaceAll('_', ' ')),
      ]),
    );
  }

  Widget _analysisRow(String label, String value, {bool danger = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))), Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: danger ? AppColors.danger : AppColors.textPrimary))]),
  );
}

// --------------------------------------------------------------------------- //
// Transaction path timeline
// --------------------------------------------------------------------------- //

class _TransactionPathTimeline extends StatelessWidget {
  final TraceResult result;
  const _TransactionPathTimeline({required this.result});

  @override
  Widget build(BuildContext context) {
    final path = result.summary.path;
    if (path.isEmpty) {
      return const Text(
        'No path to a known VASP was found within the selected hop depth.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < path.length; i++) ...[
          _PathStep(
            address: path[i],
            isTarget: i == 0,
            isVasp: i == path.length - 1 && result.summary.nearestVasp != null,
            vaspName: (i == path.length - 1) ? result.summary.nearestVasp : null,
            edge: i < path.length - 1 ? _findEdge(path[i], path[i + 1]) : null,
          ),
          if (i < path.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 15),
              child: Icon(Icons.arrow_downward, size: 16, color: AppColors.textSecondary),
            ),
        ],
      ],
    );
  }

  GraphEdge? _findEdge(String a, String b) {
    for (final e in result.edges) {
      if ((e.from == a && e.to == b) || (e.from == b && e.to == a)) return e;
    }
    return null;
  }
}

class _PathStep extends StatelessWidget {
  final String address;
  final bool isTarget;
  final bool isVasp;
  final String? vaspName;
  final GraphEdge? edge;

  const _PathStep({
    required this.address,
    required this.isTarget,
    required this.isVasp,
    this.vaspName,
    this.edge,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isVasp ? AppColors.vasp : (isTarget ? AppColors.targetAmber : AppColors.wallet);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(
            isVasp ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined,
            size: 15,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTarget ? 'Target Wallet' : (isVasp ? (vaspName ?? 'VASP') : 'Intermediate Wallet'),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(_shorten(address, keep: 10), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
              if (edge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${_edgeLabel(edge!)} · ${edge!.timestamp.split("T").first}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}