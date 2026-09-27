import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../evidence/analysis_summary_card.dart';
import '../evidence/transaction_path_timeline.dart';
import 'metric_card.dart';
import 'pattern_indicators_card.dart';
import 'score_breakdown_card.dart';
import 'vasp_provenance_card.dart';
import 'case_metadata_card.dart';

class AttributionPanel extends StatelessWidget {
  final TraceResult? result;
  final bool isExportingPdf;
  final bool isExportingCaseJson;
  final VoidCallback onExportPdf;
  final VoidCallback onExportCaseJson;

  const AttributionPanel({
    super.key,
    required this.result,
    required this.isExportingPdf,
    required this.isExportingCaseJson,
    required this.onExportPdf,
    required this.onExportCaseJson,
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
              CaseMetadataCard(metadata: result!.caseMetadata),
              MetricCard(
                title: 'Target Address',
                value: shorten(result!.summary.targetWallet, keep: 8),
                fullValue: result!.summary.targetWallet,
              ),
              MetricCard(
                title: 'Nearest VASP',
                value: result!.summary.nearestVasp ?? 'None detected',
                accentColor: result!.summary.nearestVasp != null ? AppColors.vasp : null,
              ),
              if (result!.summary.nearestVasp != null && result!.summary.vaspProvenance != null)
                VaspProvenanceCard(
                  vaspName: result!.summary.nearestVasp!,
                  provenance: result!.summary.vaspProvenance!,
                ),
              if (result!.summary.nearestVasp != null)
                MetricCard(
                  title: 'Observed VASP Path Direction',
                  value: _directionLabel(result!.summary.vaspDirection),
                  accentColor: _directionColor(result!.summary.vaspDirection),
                ),
              MetricCard(
                title: 'Hop Depth',
                value: 'Requested ${result!.summary.requestedHops} · Reached ${result!.summary.reachedHops}',
                accentColor: result!.summary.reachedHops == result!.summary.requestedHops ? AppColors.vasp : AppColors.targetAmber,
              ),
              MetricCard(
                title: 'Minimum Transfer Value',
                value: '${result!.analysis.minimumTransferEth.toStringAsFixed(4)} ETH',
              ),
              MetricCard(
                title: 'Attribution Confidence',
                value: '${result!.summary.confidenceScore} / 100',
                progressValue: result!.summary.confidenceScore / 100,
                accentColor: AppColors.primary,
              ),
              MetricCard(
                title: 'Risk Score',
                value: '${result!.summary.riskScore} / 100',
                progressValue: result!.summary.riskScore / 100,
                accentColor: result!.summary.riskScore >= 60 ? AppColors.danger : AppColors.targetAmber,
              ),
              MetricCard(
                title: 'Data Source',
                value: result!.summary.dataSource.toUpperCase(),
                accentColor: result!.summary.dataSource.startsWith('live') ? AppColors.vasp : AppColors.targetAmber,
              ),
              ScoreBreakdownCard(
                confidence: result!.summary.confidenceBreakdown,
                risk: result!.summary.riskBreakdown,
              ),
              PatternIndicatorsCard(patterns: result!.patterns),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              AnalysisSummaryCard(result: result!),
              const SizedBox(height: 12),
              const Text('Transaction Path', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              TransactionPathTimeline(result: result!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: (isExportingPdf || isExportingCaseJson) ? null : onExportPdf,
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
                            : const Icon(Icons.picture_as_pdf_outlined, size: 17),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: (isExportingPdf || isExportingCaseJson) ? null : onExportCaseJson,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isExportingCaseJson
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.data_object_outlined, size: 17),
                        label: const Text('Case JSON', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
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

String _directionLabel(String? direction) {
  switch (direction) {
    case 'outbound':
      return 'Outbound · Target → VASP';
    case 'inbound':
      return 'Inbound · VASP → Target';
    case 'mixed':
      return 'Mixed directions observed';
    default:
      return 'Unknown';
  }
}

Color _directionColor(String? direction) {
  switch (direction) {
    case 'outbound':
      return AppColors.vasp;
    case 'inbound':
      return AppColors.primary;
    case 'mixed':
      return AppColors.targetAmber;
    default:
      return AppColors.textSecondary;
  }
}
}