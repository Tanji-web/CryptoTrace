import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import 'transaction_evidence_card.dart';

class TransactionPathTimeline extends StatelessWidget {
  final TraceResult result;

  const TransactionPathTimeline({super.key, required this.result});

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
          PathStep(
            address: path[i],
            isTarget: i == 0,
            isVasp: i == path.length - 1 && result.summary.nearestVasp != null,
            vaspName: i == path.length - 1 ? result.summary.nearestVasp : null,
            hop: i < result.summary.pathHops.length ? result.summary.pathHops[i] : null,
            edges: i < result.summary.pathHops.length
                ? _edgesForHop(result.summary.pathHops[i])
                : const [],
          ),
          if (i < path.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 15),
              child: Icon(
                Icons.arrow_downward,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ],
    );
  }

  List<GraphEdge> _edgesForHop(PathHop hop) {
    final hashes = hop.transactionHashes.toSet();
    return result.edges.where((edge) => hashes.contains(edge.txHash)).toList();
  }
}

class PathStep extends StatelessWidget {
  final String address;
  final bool isTarget;
  final bool isVasp;
  final String? vaspName;
  final PathHop? hop;
  final List<GraphEdge> edges;

  const PathStep({
    super.key,
    required this.address,
    required this.isTarget,
    required this.isVasp,
    this.vaspName,
    this.hop,
    this.edges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isVasp
        ? AppColors.vasp
        : (isTarget ? AppColors.targetAmber : AppColors.wallet);

    final direction = hop?.direction;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isVasp
                ? Icons.account_balance_outlined
                : Icons.account_balance_wallet_outlined,
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
                isTarget
                    ? 'Target Wallet'
                    : (isVasp ? (vaspName ?? 'VASP') : 'Intermediate Wallet'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                shorten(address, keep: 10),
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
              ),
              if (hop != null) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DirectionBadge(direction: direction ?? 'unknown'),
                    Text(
                      '${edges.length} transaction${edges.length == 1 ? '' : 's'} on this hop',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (edges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  if (edges.length == 1)
                    TransactionEvidenceCard(
                      edge: edges.first,
                      compact: true,
                      directionLabel: _directionLabelForEdge(edges.first, hop!),
                      counterparty: _counterpartyForEdge(edges.first, hop!),
                    )
                  else
                    _HopTransactionsTile(
                      edges: edges,
                      hop: hop!,
                    ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _directionLabelForEdge(GraphEdge edge, PathHop hop) {
  if (edge.from == hop.from && edge.to == hop.to) return 'Sent to';
  if (edge.from == hop.to && edge.to == hop.from) return 'Received from';
  return 'Transaction';
}

String _counterpartyForEdge(GraphEdge edge, PathHop hop) {
  if (edge.from == hop.from && edge.to == hop.to) return hop.to;
  if (edge.from == hop.to && edge.to == hop.from) return hop.from;
  return edge.to;
}

class _DirectionBadge extends StatelessWidget {
  final String direction;

  const _DirectionBadge({required this.direction});

  @override
  Widget build(BuildContext context) {
    final label = switch (direction) {
      'outbound' => 'OUTBOUND',
      'inbound' => 'INBOUND',
      'mixed' => 'MIXED',
      _ => 'UNKNOWN',
    };

    final color = switch (direction) {
      'outbound' => AppColors.vasp,
      'inbound' => AppColors.primary,
      'mixed' => AppColors.targetAmber,
      _ => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _HopTransactionsTile extends StatelessWidget {
  final List<GraphEdge> edges;
  final PathHop hop;

  const _HopTransactionsTile({
    required this.edges,
    required this.hop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        dense: true,
        title: Text(
          'View ${edges.length} path transactions',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
        children: [
          for (final edge in edges)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TransactionEvidenceCard(
                edge: edge,
                compact: true,
                directionLabel: _directionLabelForEdge(edge, hop),
                counterparty: _counterpartyForEdge(edge, hop),
              ),
            ),
        ],
      ),
    );
  }
}