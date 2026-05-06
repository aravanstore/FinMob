import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // true - работаем с боевым сервером в офисе, false - с локальным эмулятором дома
  static const bool isProduction = false;

  static const String prodUrl = 'https://api.aravan.kg';
  static const String devUrl = 'http://192.168.2.102:3002'; // FinMob backend (3001 = AURUM web)

  final _storage = const FlutterSecureStorage();

  // Кэш токена в памяти — избегаем многократного чтения Android Keystore
  String? _cachedToken;
  Future<String?>? _tokenReadFuture;

  static Function()? onUnauthorized;
  
  // Публичный метод для обновления кэша токена (вызывается из AuthService)
  void setToken(String? token) => _cachedToken = token;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: isProduction ? prodUrl : devUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Если токена нет в кэше — читаем один раз.
        if (_cachedToken == null) {
          _tokenReadFuture ??= _storage.read(key: 'jwt_token');
          _cachedToken = await _tokenReadFuture;
          _tokenReadFuture = null;
        }
        
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          _cachedToken = null; // Сбрасываем кэш при 401
          await _storage.delete(key: 'jwt_token');
          onUnauthorized?.call();
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
  
  Future<dynamic> _requestWithCache(String path, {Map<String, dynamic>? queryParameters}) async {
    final cacheKey = 'cache_$path${queryParameters != null ? '_${queryParameters.toString()}' : ''}';
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      await prefs.setString(cacheKey, jsonEncode(response.data));
      return response.data;
    } catch (e) {
      if (e is DioException && (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.unknown || 
          e.type == DioExceptionType.connectionError)) {
        final cachedStr = prefs.getString(cacheKey);
        if (cachedStr != null) {
          return jsonDecode(cachedStr);
        }
      }
      rethrow;
    }
  }

  Future<List<dynamic>> searchClients(String query) async {
    final data = await _requestWithCache('/api/staff/clients', queryParameters: {'search': query});
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getClientDetails(String clientId) async {
    final data = await _requestWithCache('/api/staff/clients/$clientId');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getOverdueLoans() async {
    final data = await _requestWithCache('/api/staff/overdue');
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getLoanDetails(String loanId) async {
    final data = await _requestWithCache('/api/staff/loans/$loanId');
    return data as Map<String, dynamic>;
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
    final data = await _requestWithCache('/api/staff/dashboard-stats');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJournal({
    String? startDate,
    String? endDate,
    String? search,
    String? accountCode,
  }) async {
    final response = await _dio.get('/api/staff/journal', queryParameters: {
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (search != null) 'search': search,
      if (accountCode != null) 'accountCode': accountCode,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> logVisit(int clientId, double lat, double lng, String notes) async {
    await _dio.post('/api/staff/visits', data: {
      'client_id': clientId,
      'latitude': lat,
      'longitude': lng,
      'notes': notes,
    });
  }

  Future<List<dynamic>> getVisits() async {
    final response = await _dio.get('/api/staff/visits');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/staff/clients', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/staff/loans', data: data);
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

  // ─── PUSH NOTIFICATIONS ───────────────────────────────────────────────────

  // Сохранить FCM токен на сервере
  Future<void> saveFcmToken(String token) async {
    await _dio.post(
      '/api/notifications/token',
      data: {
        'fcm_token': token,
        'device_info': Platform.operatingSystem, // 'android' или 'ios'
      },
    );
  }

  // Удалить FCM токен (при логауте)
  Future<void> deleteFcmToken(String token) async {
    await _dio.delete(
      '/api/notifications/token',
      data: {'fcm_token': token},
    );
  }
}
