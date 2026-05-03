import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _api           = ApiService();
  final _loanIdCtrl    = TextEditingController();
  final _amountCtrl    = TextEditingController();
  Map<String, dynamic>? _qrData;
  bool _loading = false;
  String? _error;

  Future<void> _generateQr() async {
    final loanId = _loanIdCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));

    if (loanId.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Укажите номер кредита и сумму');
      return;
    }

    setState(() { _loading = true; _error = null; _qrData = null; });
    try {
      final data = await _api.generateQr(loanId, amount);
      setState(() => _qrData = data);
    } catch (e) {
      setState(() => _error = 'Ошибка генерации QR');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _loanIdCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Оплата через MBank',
          style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Форма
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Данные платежа',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _field(ctrl: _loanIdCtrl, label: 'Номер кредита',
                    icon: Icons.credit_card, type: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(ctrl: _amountCtrl, label: 'Сумма (сом)',
                    icon: Icons.payments, type: TextInputType.number),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _generateQr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.qr_code_2, color: Colors.white),
                      label: const Text('Сгенерировать QR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // QR-код
            if (_qrData != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _qrData!['qrCode'] as String,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Сумма: ${fmt.format(_qrData!['amount'])} сом',
                      style: const TextStyle(
                        color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Действует до: ${DateFormat('HH:mm').format(DateTime.parse(_qrData!['expiresAt']))}',
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Отсканируйте QR через приложение MBank',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5)),
      ),
    );
  }
}
