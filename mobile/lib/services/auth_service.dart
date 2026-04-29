import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _api     = ApiService();

  bool   _isLoggedIn  = false;
  String _role        = 'client'; // 'client' или 'staff'
  String _clientId    = '';
  String _fullName    = '';
  String _phone       = '';
  String _tenantName  = '';
  String _pgDatabase  = '';

  bool   get isLoggedIn  => _isLoggedIn;
  String get role        => _role;
  String get clientId    => _clientId;
  String get fullName    => _fullName;
  String get phone       => _phone;
  String get tenantName  => _tenantName;
  String get pgDatabase  => _pgDatabase;

  Future<void> init() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.isNotEmpty) {
      _role       = await _storage.read(key: 'role')        ?? 'client';
      _clientId   = await _storage.read(key: 'client_id')   ?? '';
      _fullName   = await _storage.read(key: 'full_name')   ?? '';
      _phone      = await _storage.read(key: 'phone')        ?? '';
      _tenantName = await _storage.read(key: 'tenant_name') ?? '';
      _pgDatabase = await _storage.read(key: 'pg_database') ?? '';
      _isLoggedIn = true;
    }
    notifyListeners();
  }

  Future<void> login(String pgDatabase, String phone, String pin) async {
    final data   = await _api.login(pgDatabase, phone, pin);
    final token  = data['token'] as String;
    final role   = data['role'] as String? ?? 'client';
    final client = data['client'] as Map<String, dynamic>;

    await _storage.write(key: 'jwt_token',    value: token);
    await _storage.write(key: 'role',         value: role);
    await _storage.write(key: 'client_id',    value: client['clientId']);
    await _storage.write(key: 'full_name',    value: client['fullName'] ?? '');
    await _storage.write(key: 'phone',        value: client['phone']    ?? '');
    await _storage.write(key: 'tenant_name',  value: client['tenantName'] ?? '');
    await _storage.write(key: 'pg_database',  value: pgDatabase);

    _isLoggedIn  = true;
    _role        = role;
    _clientId    = client['clientId'];
    _fullName    = client['fullName']   ?? '';
    _phone       = client['phone']      ?? '';
    _tenantName  = client['tenantName'] ?? '';
    _pgDatabase  = pgDatabase;
    notifyListeners();
  }

  Future<void> staffLogin(String pgDatabase, String username, String password) async {
    final data   = await _api.staffLogin(pgDatabase, username, password);
    final token  = data['token'] as String;
    final role   = data['role'] as String? ?? 'staff';
    final user   = data['user'] as Map<String, dynamic>;

    await _storage.write(key: 'jwt_token',    value: token);
    await _storage.write(key: 'role',         value: role);
    await _storage.write(key: 'client_id',    value: user['userId']); // using client_id key for backwards compat
    await _storage.write(key: 'full_name',    value: user['fullName'] ?? '');
    await _storage.write(key: 'phone',        value: user['username'] ?? ''); // storing username in phone for now
    await _storage.write(key: 'tenant_name',  value: user['tenantName'] ?? '');
    await _storage.write(key: 'pg_database',  value: pgDatabase);

    _isLoggedIn  = true;
    _role        = role;
    _clientId    = user['userId'];
    _fullName    = user['fullName']   ?? '';
    _phone       = user['username']   ?? '';
    _tenantName  = user['tenantName'] ?? '';
    _pgDatabase  = pgDatabase;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _isLoggedIn  = false;
    _role        = 'client';
    _clientId    = '';
    _fullName    = '';
    _phone       = '';
    _tenantName  = '';
    _pgDatabase  = '';
    notifyListeners();
  }
}
