import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/planner/application/planner_controller.dart';

class TimeWiseApp extends ConsumerStatefulWidget {
  const TimeWiseApp({super.key});

  @override
  ConsumerState<TimeWiseApp> createState() => _TimeWiseAppState();
}

class _TimeWiseAppState extends ConsumerState<TimeWiseApp> {
  late final GoRouter _router = createRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConstants.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
  );
}
