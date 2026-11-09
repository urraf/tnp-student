import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth.dart';
import '../ui/screens/applications/applications_screen.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/auth/password_screens.dart';
import '../ui/screens/auth/splash_screen.dart';
import '../ui/screens/common/pdf_viewer_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/jobs/job_detail_screen.dart';
import '../ui/screens/jobs/jobs_screen.dart';
import '../ui/screens/more/feedback_screens.dart';
import '../ui/screens/more/forms_docs_screen.dart';
import '../ui/screens/more/info_screens.dart';
import '../ui/screens/more/more_screen.dart';
import '../ui/screens/notices/notice_detail_screen.dart';
import '../ui/screens/notices/notices_screen.dart';
import '../ui/screens/profile/drop_subjects_screen.dart';
import '../ui/screens/profile/edit_profile_screen.dart';
import '../ui/screens/profile/profile_screen.dart';
import '../ui/widgets/content.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicRoutes = {'/login', '/forgot-password', '/reset-password'};

/// Notifies GoRouter whenever auth state changes so redirects re-run.
class _AuthRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authProvider.select((s) => s.status), (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final loc = state.matchedLocation;
      final isPublic = _publicRoutes.contains(loc);

      if (status == AuthStatus.unknown) return loc == '/splash' ? null : '/splash';
      if (status == AuthStatus.unauthenticated) return isPublic ? null : '/login';
      // Authenticated.
      if (isPublic || loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, s) => ResetPasswordScreen(initialCode: s.uri.queryParameters['code']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const NoticesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/jobs', builder: (_, _) => const JobsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/applications', builder: (_, _) => const ApplicationsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notice/:id',
        builder: (_, s) => NoticeDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/job/:id',
        builder: (_, s) => JobDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/profile/drop', builder: (_, _) => const DropSubjectsScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/more/forms',
        builder: (_, s) => FormsDocsScreen(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/more/feedback', builder: (_, _) => const FeedbackScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/more/my-feedbacks', builder: (_, _) => const MyFeedbacksScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/more/contact', builder: (_, _) => const ContactScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/pdf',
        builder: (_, s) => PdfViewerScreen(
          args: s.extra is PdfArgs ? s.extra as PdfArgs : const PdfArgs(url: '', title: 'Document'),
        ),
      ),
    ],
  );
});
