import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'services/auth_service.dart';
import 'services/theme_controller.dart';
import 'services/api_service.dart';
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
import 'screens/staff/journal_screen.dart';
import 'screens/staff/issue_loan_screen.dart';
import 'screens/staff/visits_screen.dart';
import 'screens/staff/client_registration_screen.dart';
import 'screens/inquiry_screen.dart';
import 'screens/notifications_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // Мгновенный старт: Flutter инициализируется быстро
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Локализацию нужно подождать (это быстро, < 100мс)
  await EasyLocalization.ensureInitialized();
  
  final apiService = ApiService();
  final authService = AuthService(apiService);
  
  PushNotificationService.init(apiService);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('ky'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ru'),
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authService),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          Provider<ApiService>.value(value: apiService),
        ],
        child: const FinCoreApp(),
      ),
    ),
  );
  
  // Инициализируем данные уже после того, как приложение отрисовало первый кадр
  await authService.init();
  if (authService.isLoggedIn) {
    // Если залогинены — принудительно обновляем токен на сервере при старте
    PushNotificationService.registerToken(apiService);
  }
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
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/staff/journal',
          builder: (_, __) => const JournalScreen(),
        ),
        GoRoute(
          path: '/staff/visits',
          builder: (_, __) => const VisitsScreen(),
        ),
        GoRoute(
          path: '/staff/register-client',
          builder: (_, __) => const ClientRegistrationScreen(),
        ),
        GoRoute(
          path: '/staff/client/:clientId/update-passport',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ClientRegistrationScreen(
              clientId: state.pathParameters['clientId'],
              initialData: extra?['client'],
            );
          },
        ),
        GoRoute(
          path: '/staff/issue-loan',
          builder: (_, __) => const IssueLoanScreen(),
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

    // Переход в историю уведомлений при клике на Push
    PushNotificationService.onNotificationClick = (message) {
      if (auth.isLoggedIn) {
        _router.push('/notifications');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();

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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeCtrl.mode,
      routerConfig: _router,
    );
  }
}
