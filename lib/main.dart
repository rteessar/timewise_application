import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timewise_application/core/router/app_router.dart';
import 'package:timewise_application/core/theme/app_theme.dart';
import 'package:timewise_application/core/constants/app_constants.dart';
import 'package:timewise_application/core/services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database
  await DatabaseService.initialize();

  runApp(
    const ProviderScope(
      child: TimeWiseApp(),
    ),
  );
}

class TimeWiseApp extends StatelessWidget {
  const TimeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
