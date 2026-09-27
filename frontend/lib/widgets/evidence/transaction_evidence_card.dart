import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class TransactionEvidenceCard extends StatelessWidget {
  final GraphEdge edge;
  final String? directionLabel;
  final String? counterparty;
  final bool compact;

  const TransactionEvidenceCard({
    super.key,
    required this.edge,
    this.directionLabel,
    this.counterparty,
    this.compact = false,
  });

  Future<void> _openExplorer(BuildContext context) async {
    final url = edge.explorerUrl;
    if (url == null) return;

    try {
      final launched = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_blank',
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the transaction explorer link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the transaction explorer link.')),
        );
      }
    }
  }

  String _displayType() {
    if (edge.assetType == 'contract_interaction') return 'Contract interaction';
    return edge.transactionType.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final heading = counterparty == null
        ? 'Transaction Evidence'
        : '${directionLabel ?? 'Transaction'} ${shorten(counterparty!)}';

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                edgeLabel(edge),
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _displayType(),
                style: TextStyle(
                  fontSize: compact ? 10 : 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (edge.blockNumber != null)
                Text(
                  'Block ${edge.blockNumber}',
                  style: TextStyle(
                    fontSize: compact ? 10 : 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            edge.timestamp,
            style: TextStyle(fontSize: compact ? 9.5 : 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          SelectableText(
            edge.txHash.isEmpty ? 'Transaction hash unavailable' : edge.txHash,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10,
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          if (edge.tokenContract != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              'Token contract: ${edge.tokenContract}',
              style: TextStyle(fontSize: compact ? 9.5 : 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
            ),
          ],
          if (edge.explorerUrl != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openExplorer(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('View on Etherscan'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Demo transaction: no live explorer record',
              style: TextStyle(
                fontSize: compact ? 9.5 : 10,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
