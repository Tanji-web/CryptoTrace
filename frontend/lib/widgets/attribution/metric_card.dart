import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? fullValue;
  final Color? accentColor;
  final double? progressValue;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.fullValue,
    this.accentColor,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Tooltip(
            message: fullValue ?? '',
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accentColor ?? AppColors.textPrimary,
                fontFamily: fullValue != null ? 'monospace' : null,
              ),
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: accentColor ?? AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}