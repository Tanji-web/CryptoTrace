import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';

class VaspProvenanceCard extends StatelessWidget {
  final String vaspName;
  final VaspProvenance provenance;

  const VaspProvenanceCard({
    super.key,
    required this.vaspName,
    required this.provenance,
  });

  @override
  Widget build(BuildContext context) {
    final isDemo = provenance.verificationStatus.toLowerCase() == 'demo';
    final statusColor = isDemo ? AppColors.targetAmber : AppColors.vasp;
    final statusLabel = isDemo
        ? 'Demo / Not Independently Verified'
        : provenance.verificationStatus.replaceAll('_', ' ').toUpperCase();

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
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'VASP Provenance',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _row('Entity', vaspName),
          _row('Registry source', provenance.source),
          _row('Source type', provenance.sourceType.replaceAll('_', ' ')),
          _row(
            'Last verified',
            provenance.lastVerified?.isNotEmpty == true ? provenance.lastVerified! : 'Not provided',
          ),
          if (provenance.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            const Text(
              'Notes',
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              provenance.notes!,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35),
            ),
          ],
          if (provenance.sourceUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openSource(provenance.sourceUrl!),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open public source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }
}
