import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_store.dart';

class SignalScopeApp extends StatelessWidget {
  final SettingsStore settings;
  const SignalScopeApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Scope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.bgBottom,
      ),
      home: DashboardScreen(settings: settings),
    );
  }
}
