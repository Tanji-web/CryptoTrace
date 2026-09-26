import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../evidence/analysis_summary_card.dart';
import '../evidence/transaction_path_timeline.dart';
import 'metric_card.dart';

class AttributionPanel extends StatelessWidget {
  final TraceResult? result;
  final bool isExportingPdf;
  final VoidCallback onExportPdf;

  const AttributionPanel({
    super.key,
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
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              AnalysisSummaryCard(result: result!),
              const SizedBox(height: 12),
              const Text('Transaction Path', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              TransactionPathTimeline(result: result!),
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