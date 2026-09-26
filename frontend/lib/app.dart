import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'theme/app_colors.dart';

class CryptoTraceApp extends StatelessWidget {
  const CryptoTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptoTrace — VASP Attribution Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        dividerColor: AppColors.border,
      ),
      home: const CryptoTraceHomePage(),
    );
  }
}
