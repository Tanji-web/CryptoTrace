import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';

class AnalysisSummaryCard extends StatelessWidget {
  final TraceResult result;
  const AnalysisSummaryCard({super.key, required this.result});

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
        _analysisRow('Unpriced token transfers seen', '${a.unpricedTokenTransactions}'),
        _analysisRow('Candidate limit', '${a.filteredCandidateLimit}'),
        _analysisRow('Contract interactions', '${a.contractInteractions}'),
        _analysisRow('Non-economic contract calls', '${a.filteredNonEconomicContractCalls}'),
        _analysisRow('Other filtered', '${a.filteredOther}'),
        _analysisRow('Internal ETH transfers', '${a.internalEthTransactions}'),
        _analysisRow('ERC-20 transfers traced structurally', '${a.erc20Transactions}'),
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