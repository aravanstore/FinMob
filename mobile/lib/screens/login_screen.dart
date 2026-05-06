import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/theme_controller.dart';
import '../widgets/loan_calculator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _dbCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _isStaff = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _login() async {
    final db = _dbCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (db.isEmpty || phone.isEmpty || pin.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isStaff) {
        await context.read<AuthService>().staffLogin(db, phone, pin);
      } else {
        await context.read<AuthService>().login(db, phone, pin);
      }
      if (mounted) {
        context.go(_isStaff ? '/staff' : '/dashboard');
      }
    } on Exception catch (e) {
      setState(() => _error = 'Ошибка входа: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _dbCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: false,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF1A56DB)),
              const SizedBox(height: 24),
              const Text('AURUM / FinCore', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              
              // Переключатель Заемщик / Сотрудник
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roleBtn(false, 'Заёмщик'),
                  const SizedBox(width: 12),
                  _roleBtn(true, 'Сотрудник'),
                ],
              ),
              const SizedBox(height: 32),

              _field(ctrl: _dbCtrl, label: 'Код организации', icon: Icons.business),
              const SizedBox(height: 16),
              _field(ctrl: _phoneCtrl, label: 'Логин / Телефон', icon: Icons.person),
              const SizedBox(height: 16),
              _field(ctrl: _pinCtrl, label: 'Пароль / PIN', icon: Icons.lock, obscure: true),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('ВОЙТИ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
              ],

              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () => LoanCalculator.show(context),
                icon: const Icon(Icons.calculate, color: Colors.white54),
                label: const Text('Калькулятор займа', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleBtn(bool staff, String label) {
    final active = _isStaff == staff;
    return GestureDetector(
      onTap: () => setState(() => _isStaff = staff),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A56DB) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54)),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2)
        ),
      ),
    );
  }
}
