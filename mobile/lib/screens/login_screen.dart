import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/theme_controller.dart';

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
        if (pin.length < 4) {
          setState(() {
            _error = 'PIN — минимум 4 цифры';
            _loading = false;
          });
          return;
        }
        await context.read<AuthService>().login(db, phone, pin);
      }
      if (mounted) {
        context.go(_isStaff ? '/staff' : '/dashboard');
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('404')) {
        setState(() => _error = _isStaff
            ? 'Пользователь или организация не найдены'
            : 'Клиент или организация не найдены');
      } else if (msg.contains('401')) {
        setState(() => _error = _isStaff ? 'Неверный пароль' : 'Неверный PIN');
      } else if (msg.contains('403')) {
        setState(() => _error = 'Доступ заблокирован');
      } else {
        setState(() => _error = 'Ошибка подключения к серверу');
      }
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    context.watch<ThemeController>().isLight
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => context.read<ThemeController>().toggle(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Лого
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 20),
                      const Text('FinCore',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 6),
                      Text(_isStaff ? 'staff.dashboard'.tr() : 'login.title'.tr(),
                          style:
                              const TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 20),

                  // Выбор языка
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final entry in [
                        ('RU', const Locale('ru')),
                        ('KY', const Locale('ky')),
                        ('EN', const Locale('en')),
                      ])
                        TextButton(
                          onPressed: () {
                            EasyLocalization.of(context)!.setLocale(entry.$2);
                          },
                          child: Text(entry.$1,
                              style: TextStyle(
                                color: context.locale.languageCode ==
                                        entry.$2.languageCode
                                    ? Colors.white
                                    : Colors.white38,
                                fontWeight: context.locale.languageCode ==
                                        entry.$2.languageCode
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Переключатель Заемщик / Сотрудник
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Заёмщик'),
                        selected: !_isStaff,
                        onSelected: (val) => setState(() => _isStaff = false),
                        selectedColor: const Color(0xFF1A56DB).withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                            color: !_isStaff ? Colors.white : Colors.white54),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Сотрудник'),
                        selected: _isStaff,
                        onSelected: (val) => setState(() => _isStaff = true),
                        selectedColor: const Color(0xFF1A56DB).withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                            color: _isStaff ? Colors.white : Colors.white54),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _field(
                    ctrl: _dbCtrl,
                    label: 'login.org_code'.tr(),
                    hint: 'login.org_code_hint'.tr(),
                    icon: Icons.business,
                  ),
                  if (!_isStaff) ...[
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '  Код выдаётся сотрудником МФО',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _phoneCtrl,
                    label: _isStaff ? 'Логин' : 'login.phone'.tr(),
                    icon: _isStaff ? Icons.person : Icons.phone,
                    type: _isStaff ? TextInputType.text : TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _pinCtrl,
                    label: _isStaff ? 'Пароль' : 'login.pin'.tr(),
                    icon: Icons.lock,
                    obscure: true,
                    type: _isStaff ? TextInputType.text : TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Ошибка
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13))),
                          ],
                        ),
                      ),
                    ),

                  // Кнопка Войти
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('login.button'.tr(),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2)),
      ),
    );
  }
}
