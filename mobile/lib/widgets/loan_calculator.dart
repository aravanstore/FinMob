import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';

class LoanCalculator extends StatefulWidget {
  const LoanCalculator({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LoanCalculator(),
    );
  }

  @override
  State<LoanCalculator> createState() => _LoanCalculatorState();
}

class _LoanCalculatorState extends State<LoanCalculator> {
  final _amountCtrl = TextEditingController(text: '100000');
  final _termCtrl = TextEditingController(text: '12');
  final _rateCtrl = TextEditingController(text: '30');

  String _productType = 'Аннуитет (равные платежи)';

  final List<String> _products = [
    'Аннуитет (равные платежи)',
    'В конце срока (ежемесячно только %, ОД в конце)',
    'Дифференцированный (убывающие платежи)',
    'Квартальное погашение основного долга',
    'Гибкий (по периодам)',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _termCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  // Расчет платежей
  Map<String, dynamic> _calculate() {
    final double p = double.tryParse(_amountCtrl.text) ?? 0;
    final int n = int.tryParse(_termCtrl.text) ?? 0;
    final double rateAnnual = double.tryParse(_rateCtrl.text) ?? 0;

    if (p <= 0 || n <= 0 || rateAnnual <= 0) {
      return {'error': 'Введите корректные данные'};
    }

    final double r = (rateAnnual / 100) / 12; // monthly rate

    if (_productType == 'Аннуитет (равные платежи)' || _productType == 'Ипотека (равные платежи)') {
      final double pmt = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
      final double total = pmt * n;
      return {
        'payment': pmt,
        'paymentLabel': 'Ежемесячный платёж',
        'total': total,
        'overpayment': total - p,
      };
    } else if (_productType == 'В конце срока (ежемесячно только %, ОД в конце)') {
      final double interestMonthly = p * r;
      final double total = (interestMonthly * n) + p;
      return {
        'payment': interestMonthly,
        'paymentLabel': 'Ежемесячно (только %)',
        'lastPayment': p + interestMonthly,
        'total': total,
        'overpayment': total - p,
      };
    } else if (_productType == 'Дифференцированный (убывающие платежи)') {
      final double principalPart = p / n;
      final double firstInterest = p * r;
      final double lastInterest = principalPart * r; // roughly
      final double firstPmt = principalPart + firstInterest;
      final double lastPmt = principalPart + lastInterest;
      
      // Точный расчет:
      double totalInterest = 0;
      double bal = p;
      for(int i=0; i<n; i++) {
         totalInterest += bal * r;
         bal -= principalPart;
      }
      
      return {
        'payment': firstPmt,
        'paymentLabel': 'Первый платёж',
        'lastPayment': lastPmt,
        'total': p + totalInterest,
        'overpayment': totalInterest,
      };
    } else if (_productType == 'Квартальное погашение основного долга') {
      // Упрощенный расчет: % ежемесячно, ОД раз в 3 месяца
      final double rQ = (rateAnnual / 100) / 4;
      final int nQ = (n / 3).ceil();
      final double pmtQ = (p * rQ * pow(1 + rQ, nQ)) / (pow(1 + rQ, nQ) - 1);
      final double total = pmtQ * nQ;
      return {
        'payment': pmtQ,
        'paymentLabel': 'Квартальный платёж',
        'total': total,
        'overpayment': total - p,
      };
    } else {
      // Гибкий - приблизительно как аннуитет
      final double pmt = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
      final double total = pmt * n;
      return {
        'payment': pmt,
        'paymentLabel': 'Средний платёж (гибкий)',
        'total': total,
        'overpayment': total - p,
      };
    }
  }

  String _format(double v) {
    return NumberFormat.currency(locale: 'ru_RU', symbol: 'сом', decimalDigits: 0).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPri = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSec = isDark ? Colors.white70 : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    final res = _calculate();
    final hasError = res.containsKey('error');

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Калькулятор займа', style: TextStyle(color: textPri, fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close, color: textSec),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Form
              Text('Тип продукта', style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _productType,
                    isExpanded: true,
                    dropdownColor: bg,
                    icon: Icon(Icons.keyboard_arrow_down, color: textSec),
                    style: TextStyle(color: textPri, fontSize: 15),
                    onChanged: (v) => setState(() => _productType = v!),
                    items: _products.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildField('Сумма (сом)', _amountCtrl, inputBg, textPri, textSec),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildField('Срок (мес)', _termCtrl, inputBg, textPri, textSec),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildField('Процентная ставка (% годовых)', _rateCtrl, inputBg, textPri, textSec),
              
              const SizedBox(height: 24),

              // Results
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: hasError
                    ? Text(res['error'], style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center)
                    : Column(
                        children: [
                          Text(res['paymentLabel'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(_format(res['payment']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          
                          if (res.containsKey('lastPayment')) ...[
                            const SizedBox(height: 8),
                            Text('Последний платёж', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(_format(res['lastPayment']), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white24, height: 1),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Переплата', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(_format(res['overpayment']), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Итого к возврату', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(_format(res['total']), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              // Hint
              const Text('Расчеты носят предварительный характер и могут незначительно отличаться при подписании договора в зависимости от точных дат и комиссий.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, Color bg, Color textPri, Color textSec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textPri, fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
