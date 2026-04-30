import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/history_screen.dart';
import 'screens/shares_history_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';
import 'screens/staff/client_details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final authService = AuthService();
  await authService.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('kg')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      child: ChangeNotifierProvider(
        create: (_) => authService,
        child: const FinCoreApp(),
      ),
    ),
  );
}

class FinCoreApp extends StatelessWidget {
  const FinCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    final router = GoRouter(
      initialLocation: auth.isLoggedIn
          ? (auth.role == 'staff' ? '/staff' : '/dashboard')
          : '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(
            path: '/staff', builder: (_, __) => const StaffDashboardScreen()),
        GoRoute(
          path: '/staff/client/:clientId',
          builder: (_, state) => ClientDetailsScreen(
            clientId: state.pathParameters['clientId']!,
          ),
        ),
        GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
        GoRoute(
          path: '/schedule/:loanId',
          builder: (_, state) => ScheduleScreen(
            loanId: state.pathParameters['loanId']!,
          ),
        ),
        GoRoute(
          path: '/history/:loanId',
          builder: (_, state) => HistoryScreen(
            loanId: state.pathParameters['loanId']!,
          ),
        ),
        GoRoute(
          path: '/shares-history',
          builder: (_, __) => const SharesHistoryScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'FinCore',
      debugShowCheckedModeBanner: false,

      // Настройки локализации
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56DB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
