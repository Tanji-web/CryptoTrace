import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trace_models.dart';
import '../services/api_client.dart';
import '../widgets/attribution/attribution_panel.dart';
import '../widgets/graph/transaction_graph.dart';
import '../widgets/header_bar.dart';
import '../widgets/input_panel.dart';

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
  bool _errorRetryable = false;
  TraceResult? _result;
  String? _selectedNodeId;
  bool _backendOnline = false;
  bool _isExportingPdf = false;
  bool _isExportingCaseJson = false;
  bool _showEvidencePanel = true;
  Timer? _healthTimer;

  static final RegExp _addressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

  @override
  void initState() {
    super.initState();
    _pollHealth();
    _healthTimer = Timer.periodic(const Duration(seconds: 8), (_) => _pollHealth());
  }

  Future<void> _pollHealth() async {
    final online = await ApiClient.checkHealth();
    if (!mounted) return;
    setState(() => _backendOnline = online);
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
    final wallet = _addressController.text.trim().toLowerCase();
    final validationError = _validateAddress(wallet);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _errorRetryable = false;
        _result = null;
        _selectedNodeId = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorRetryable = false;
      // Clear the previous result while a new trace is running so stale
      // evidence cannot be mistaken for the in-progress request.
      _result = null;
      _selectedNodeId = null;
    });

    try {
      final result = await ApiClient.traceWallet(wallet, _hopDepth);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
        _errorMessage = null;
        _errorRetryable = false;
        _selectedNodeId = result.summary.targetWallet;
        _backendOnline = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _errorRetryable = e.retryable;
        _isLoading = false;
        if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
          _backendOnline = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred while tracing the wallet. Please retry.';
        _errorRetryable = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_result == null || _isExportingPdf || _isExportingCaseJson) return;
    setState(() => _isExportingPdf = true);

    final uri = ApiClient.reportUri(
      _result!.summary.targetWallet,
      _result!.summary.requestedHops,
      caseId: _result!.caseMetadata.caseId,
    );
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) throw Exception('launch failed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the evidence PDF. Check the backend and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportCaseJson() async {
    if (_result == null || _isExportingPdf || _isExportingCaseJson) return;
    setState(() => _isExportingCaseJson = true);

    final uri = ApiClient.caseJsonUri(
      _result!.summary.targetWallet,
      _result!.summary.requestedHops,
      caseId: _result!.caseMetadata.caseId,
    );
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) throw Exception('launch failed');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the case JSON. Check the backend and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCaseJson = false);
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
            HeaderBar(backendOnline: _backendOnline, onStatusTap: _pollHealth),
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
                          child: InputPanel(
                            controller: _addressController,
                            hopDepth: _hopDepth,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            errorRetryable: _errorRetryable,
                            onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                            onTrace: _runTrace,
                            onRetry: _runTrace,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: GraphSection(
                            result: _result,
                            isLoading: _isLoading,
                            selectedNodeId: _selectedNodeId,
                            onNodeSelected: (id) => setState(() => _selectedNodeId = id),
                            onToggleEvidencePanel: () => setState(() => _showEvidencePanel = !_showEvidencePanel),
                            evidencePanelVisible: _showEvidencePanel,
                          ),
                        ),
                        if (_showEvidencePanel) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: 340,
                            child: AttributionPanel(
                              result: _result,
                              isExportingPdf: _isExportingPdf,
                              isExportingCaseJson: _isExportingCaseJson,
                              onExportPdf: _exportPdf,
                              onExportCaseJson: _exportCaseJson,
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        InputPanel(
                          controller: _addressController,
                          hopDepth: _hopDepth,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          errorRetryable: _errorRetryable,
                          onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                          onTrace: _runTrace,
                          onRetry: _runTrace,
                        ),
                        SizedBox(
                          height: 420,
                          child: GraphSection(
                            result: _result,
                            isLoading: _isLoading,
                            selectedNodeId: _selectedNodeId,
                            onNodeSelected: (id) => setState(() => _selectedNodeId = id),
                          ),
                        ),
                        AttributionPanel(
                          result: _result,
                          isExportingPdf: _isExportingPdf,
                          isExportingCaseJson: _isExportingCaseJson,
                          onExportPdf: _exportPdf,
                          onExportCaseJson: _exportCaseJson,
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
