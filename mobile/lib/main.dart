import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/history_screen.dart';
import 'screens/shares_history_screen.dart';
import 'screens/staff/staff_dashboard_screen.dart';
import 'screens/staff/client_details_screen.dart';
import 'screens/staff/loan_details_screen.dart';
import 'screens/staff/share_details_screen.dart';
import 'screens/inquiry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final authService = AuthService();
  await authService.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('ky'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      useOnlyLangCode: true,
      saveLocale: false,
      child: ChangeNotifierProvider(
        create: (_) => authService,
        child: FinCoreApp(),
      ),
    ),
  );
}

class FinCoreApp extends StatefulWidget {
  const FinCoreApp({super.key});

  @override
  State<FinCoreApp> createState() => _FinCoreAppState();
}

class _FinCoreAppState extends State<FinCoreApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();

    _router = GoRouter(
      refreshListenable: auth,
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
        GoRoute(
          path: '/staff/client/:clientId/shares',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ShareDetailsScreen(
              clientId: state.pathParameters['clientId']!,
              clientName: extra?['name'] ?? 'Клиент',
            );
          },
        ),
        GoRoute(
          path: '/staff/loan/:loanId',
          builder: (_, state) => LoanDetailsScreen(
            loanId: state.pathParameters['loanId']!,
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
        GoRoute(
          path: '/inquiry',
          builder: (_, __) => const InquiryScreen(),
        ),
      ],
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final goingToLogin = state.matchedLocation == '/login';

        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) {
          return auth.role == 'staff' ? '/staff' : '/dashboard';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FinCore',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56DB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
