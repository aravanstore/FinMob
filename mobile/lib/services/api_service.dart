import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // true - работаем с боевым сервером в офисе, false - с локальным эмулятором дома
  static const bool isProduction = false;

  static const String prodUrl = 'https://api.aravan.kg';
  static const String devUrl = 'http://10.0.2.2:3002'; // FinMob backend (3001 = AURUM web)

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
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Токен истёк или невалиден — чистим хранилище
          await _storage.delete(key: 'jwt_token');
        }
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
      'phone': phone,
      'pin': pin,
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
      'username': username,
      'password': password,
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

  // ─── STAFF ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> searchClients(String query) async {
    final response = await _dio
        .get('/api/staff/clients', queryParameters: {'search': query});
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getClientDetails(String clientId) async {
    final response = await _dio.get('/api/staff/clients/$clientId');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getOverdueLoans() async {
    final response = await _dio.get('/api/staff/overdue');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getLoanDetails(String loanId) async {
    final response = await _dio.get('/api/staff/loans/$loanId');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getClientShareHistory(String clientId) async {
    final response = await _dio.get('/api/staff/clients/$clientId/shares');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getApprovals() async {
    final response = await _dio.get('/api/staff/approvals');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/api/staff/dashboard-stats');
    return response.data as Map<String, dynamic>;
  }

  Future<void> sendInquiry(String type, String message) async {
    await _dio.post('/api/inquiries', data: {
      'type': type,
      'message': message,
    });
  }

  Future<List<dynamic>> getInquiries() async {
    final response = await _dio.get('/api/inquiries');
    return response.data as List<dynamic>;
  }

  Future<dynamic> getActiveAnnouncement() async {
    try {
      final response = await _dio.get('/api/announcements/active');
      return response.data;
    } catch (e) {
      return null;
    }
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
