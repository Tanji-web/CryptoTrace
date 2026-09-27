import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';

class ScoreBreakdownCard extends StatelessWidget {
  final ScoreBreakdown? confidence;
  final ScoreBreakdown? risk;

  const ScoreBreakdownCard({
    super.key,
    required this.confidence,
    required this.risk,
  });

  @override
  Widget build(BuildContext context) {
    if (confidence == null && risk == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: const Icon(Icons.rule_folder_outlined, size: 18, color: AppColors.primary),
          title: const Text(
            'Why these scores?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Transparent heuristic factor breakdown',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          children: [
            if (confidence != null) _BreakdownSection(breakdown: confidence!),
            if (risk != null) _BreakdownSection(breakdown: risk!),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final ScoreBreakdown breakdown;

  const _BreakdownSection({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final isConfidence = breakdown.scoreType == 'confidence';
    final accent = isConfidence ? AppColors.primary : AppColors.targetAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isConfidence ? 'Confidence' : 'Risk',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${breakdown.finalScore} / 100',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _ScoreLine(label: 'Base score', points: breakdown.baseScore, showSign: false),
          const SizedBox(height: 5),
          for (final factor in breakdown.factors) ...[
            _ScoreLine(label: factor.label, points: factor.points),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 1, bottom: 4),
              child: Text(
                factor.explanation,
                style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, height: 1.3),
              ),
            ),
          ],
          const Divider(height: 12),
          Row(
            children: [
              const Text('Final heuristic score', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${breakdown.finalScore}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final String label;
  final int points;
  final bool showSign;

  const _ScoreLine({required this.label, required this.points, this.showSign = true});

  @override
  Widget build(BuildContext context) {
    final pointsText = showSign && points > 0
        ? '+$points'
        : points.toString();
    final pointColor = points > 0
        ? AppColors.vasp
        : points < 0
            ? AppColors.danger
            : AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          pointsText,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pointColor),
        ),
      ],
    );
  }
}
