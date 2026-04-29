import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// FinCore Mobile API base URL
/// В продакшне замените на ваш Cloudflare Tunnel домен
const _baseUrl = 'http://10.0.2.2:3002';
// Для реального телефона используйте IP вашего ПК:
// const _baseUrl = 'http://192.168.1.XXX:3002';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // true - работаем с боевым сервером в офисе, false - с локальным эмулятором дома
  static const bool isProduction = true; 
  
  static const String prodUrl = 'https://api.aravan.kg';
  static const String devUrl  = 'http://10.0.2.2:3002';

  final _storage = const FlutterSecureStorage();

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: isProduction ? prodUrl : devUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // 401 — выбросим чтобы AuthService поймал и разлогинил
        return handler.next(e);
      },
    ));

  // ─── AUTH ──────────────────────────────────────────────────────────────────

  /// Вход: pg_database = имя БД МФО (напр. "aravan_1")
  Future<Map<String, dynamic>> login(
    String pgDatabase,
    String phone,
    String pin,
  ) async {
    final response = await _dio.post('/api/auth/login', data: {
      'pg_database': pgDatabase,
      'phone':       phone,
      'pin':         pin,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> staffLogin(
    String pgDatabase,
    String username,
    String password,
  ) async {
    final response = await _dio.post('/api/auth/staff-login', data: {
      'pg_database': pgDatabase,
      'username':    username,
      'password':    password,
    });
    return response.data as Map<String, dynamic>;
  }

  // ─── LOANS ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getLoans() async {
    final response = await _dio.get('/api/loans');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getLoan(String loanId) async {
    final response = await _dio.get('/api/loans/$loanId');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getLoanSchedule(String loanId) async {
    final response = await _dio.get('/api/loans/$loanId/schedule');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getLoanTransactions(String loanId) async {
    final response = await _dio.get('/api/loans/$loanId/transactions');
    return response.data as List<dynamic>;
  }

  // ─── SHARES ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSharesSummary() async {
    final response = await _dio.get('/api/shares/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSharesHistory() async {
    final response = await _dio.get('/api/shares/history');
    return response.data as List<dynamic>;
  }

  // ─── PAYMENTS ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateQr(String loanId, double amount) async {
    final response = await _dio.post('/api/payments/qr', data: {
      'loanId': loanId,
      'amount': amount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPaymentSummary() async {
    final response = await _dio.get('/api/payments/summary');
    return response.data as Map<String, dynamic>;
  }

  // ─── HEALTH ───────────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}
