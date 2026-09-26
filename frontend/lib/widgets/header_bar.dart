import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HeaderBar extends StatelessWidget {
  final bool backendOnline;
  final VoidCallback onStatusTap;
  const HeaderBar({super.key, required this.backendOnline, required this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'CryptoTrace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          const Text(
            '— VASP Attribution Portal',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Tooltip(
            message: 'Tap to re-check backend connection',
            child: GestureDetector(
              onTap: onStatusTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: backendOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: backendOnline ? AppColors.vasp : AppColors.danger, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backendOnline ? AppColors.vasp : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      backendOnline ? 'Status: Online' : 'Status: Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: backendOnline ? AppColors.vasp : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
