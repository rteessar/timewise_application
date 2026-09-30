import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/project_composer/presentation/project_composer_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/timeline/presentation/timeline_screen.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: '/timeline',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/timeline',
              builder: (_, _) => const TimelineScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/project/new',
      builder: (_, _) => const ProjectComposerScreen(),
    ),
    GoRoute(
      path: '/project/:id',
      builder: (_, s) =>
          ProjectComposerScreen(projectId: s.pathParameters['id']),
    ),
  ],
);
