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
  TraceResult? _result;
  String? _selectedNodeId;
  bool _backendOnline = false;
  bool _isExportingPdf = false;
  bool _isExportingCaseJson = false;
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

    final uri = ApiClient.reportUri(
      _result!.summary.targetWallet,
      _result!.summary.requestedHops,
      caseId: _result!.caseMetadata.caseId,
    );
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

  Future<void> _exportCaseJson() async {
    if (_result == null) return;
    setState(() => _isExportingCaseJson = true);

    final uri = ApiClient.caseJsonUri(
      _result!.summary.targetWallet,
      _result!.summary.requestedHops,
      caseId: _result!.caseMetadata.caseId,
    );
    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched) {
        throw Exception('launch failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate or open the case JSON. Please try again.')),
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
                            onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                            onTrace: _runTrace,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: GraphSection(
                            result: _result,
                            isLoading: _isLoading,
                            selectedNodeId: _selectedNodeId,
                            onNodeSelected: (id) => setState(() => _selectedNodeId = id),
                          ),
                        ),
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
                    );
                  }
                  // Narrow / mobile layout: stack panels vertically.
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        InputPanel(
                          controller: _addressController,
                          hopDepth: _hopDepth,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onHopDepthChanged: (v) => setState(() => _hopDepth = v),
                          onTrace: _runTrace,
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
