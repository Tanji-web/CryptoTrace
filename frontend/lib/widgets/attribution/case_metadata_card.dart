import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';

class CaseMetadataCard extends StatelessWidget {
  final CaseMetadata metadata;

  const CaseMetadataCard({
    super.key,
    required this.metadata,
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
          const Text(
            'Investigation Case',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SelectableText(
            metadata.caseId,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Text(
            metadata.createdAt.isEmpty ? 'Created time unavailable' : _formatCreatedAt(metadata.createdAt),
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'Case schema ${metadata.schemaVersion}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatCreatedAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.replaceFirst('T', ' ');
    final utc = parsed.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }
}
