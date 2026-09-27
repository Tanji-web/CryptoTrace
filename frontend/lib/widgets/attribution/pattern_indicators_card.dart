import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';

class PatternIndicatorsCard extends StatelessWidget {
  final List<PatternIndicator> patterns;

  const PatternIndicatorsCard({
    super.key,
    required this.patterns,
  });

  @override
  Widget build(BuildContext context) {
    if (patterns.isEmpty) return const SizedBox.shrink();

    final attentionCount = patterns.where((pattern) => pattern.severity == 'attention').length;

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
          leading: const Icon(Icons.insights_outlined, size: 18, color: AppColors.targetAmber),
          title: Text(
            'Pattern indicators (${patterns.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            attentionCount > 0
                ? '$attentionCount activity pattern(s) need review'
                : 'Graph-derived investigation indicators',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          children: [
            for (final pattern in patterns) PatternIndicatorItem(pattern: pattern),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'These indicators describe transaction structure or timing. They do not prove illicit activity, intent, ownership, or control.',
                style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatternIndicatorItem extends StatelessWidget {
  final PatternIndicator pattern;

  const PatternIndicatorItem({
    super.key,
    required this.pattern,
  });

  @override
  Widget build(BuildContext context) {
    final isAttention = pattern.severity == 'attention';
    final accent = isAttention ? AppColors.targetAmber : AppColors.primary;
    final evidenceText = _buildEvidenceText(pattern);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isAttention ? Icons.warning_amber_rounded : Icons.info_outline,
                size: 17,
                color: accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  pattern.label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pattern.severity,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pattern.description,
            style: const TextStyle(fontSize: 9.8, color: AppColors.textSecondary, height: 1.35),
          ),
          if (evidenceText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              evidenceText,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
          if (pattern.nodeIds.isNotEmpty || pattern.txHashes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (pattern.nodeIds.isNotEmpty) '${pattern.nodeIds.length} node(s)',
                if (pattern.txHashes.isNotEmpty) '${pattern.txHashes.length} transaction(s)',
              ].join(' · '),
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _buildEvidenceText(PatternIndicator pattern) {
    if (pattern.evidence.isEmpty) return '';
    final parts = <String>[];
    for (final entry in pattern.evidence.entries.take(3)) {
      final label = _humanize(entry.key);
      final value = entry.value;
      if (value is num && entry.key.endsWith('_eth')) {
        parts.add('$label: ${value.toStringAsFixed(6)} ETH');
      } else {
        parts.add('$label: $value');
      }
    }
    return parts.join(' · ');
  }

  String _humanize(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
