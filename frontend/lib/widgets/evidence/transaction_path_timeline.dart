import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

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
            vaspName: (i == path.length - 1) ? result.summary.nearestVasp : null,
            edge: i < path.length - 1 ? findEdge(path[i], path[i + 1]) : null,
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

  GraphEdge? findEdge(String a, String b) {
    for (final e in result.edges) {
      if ((e.from == a && e.to == b) || (e.from == b && e.to == a)) return e;
    }
    return null;
  }
}

class PathStep extends StatelessWidget {
  final String address;
  final bool isTarget;
  final bool isVasp;
  final String? vaspName;
  final GraphEdge? edge;

  const PathStep({
    super.key,
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
              Text(shorten(address, keep: 10), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
              if (edge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${edgeLabel(edge!)} · ${edge!.timestamp.split("T").first}',
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