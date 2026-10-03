import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../screens/auth/auth_screens.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/records/record_screens.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../services/finance_engine.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(profileProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      const authRoutes = {'/login', '/register', '/forgot-password'};
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      if (auth.value == null) return authRoutes.contains(location) ? null : '/login';
      final profile = ref.read(profileProvider);
      if (profile.isLoading || profile.value == null) {
        return location == '/splash' ? null : '/splash';
      }
      final done = profile.value?.onboardingCompleted ?? false;
      if (!done && location != '/onboarding') return '/onboarding';
      final leavingAuth = authRoutes.contains(location) || location == '/onboarding' || location == '/splash';
      if (done && leavingAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/transactions', builder: (_, _) => const TransactionsScreen()),
          GoRoute(path: '/incomes', builder: (_, _) => const TransactionsScreen(fixedKind: TxKind.income)),
          GoRoute(path: '/expenses', builder: (_, _) => const TransactionsScreen(fixedKind: TxKind.expense)),
          GoRoute(path: '/accounts', builder: (_, _) => const AccountsScreen()),
          GoRoute(path: '/cards', builder: (_, _) => const CardsScreen()),
          GoRoute(path: '/invoices', builder: (_, _) => const InvoicesScreen()),
          GoRoute(path: '/transfers', builder: (_, _) => const TransfersScreen()),
          GoRoute(path: '/recurring', builder: (_, _) => const RecurringScreen()),
          GoRoute(path: '/goals', builder: (_, _) => const GoalsScreen()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
