import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class _C {
  static const bg       = Color(0xFF080E1A);
  static const surface  = Color(0xFF0F1829);
  static const card     = Color(0xFF141F33);
  static const border   = Color(0xFF1E2D47);
  static const accent   = Color(0xFF2563EB);
  static const textPri  = Color(0xFFEFF6FF);
  static const textSec  = Color(0xFF64748B);
  static const green    = Color(0xFF10B981);
  static const red      = Color(0xFFEF4444);
  static const orange   = Color(0xFFF97316);
}

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _loanFuture;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _loanFuture = _api.getLoanDetails(widget.loanId);
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final df  = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        title: const Text('Детали кредита', style: TextStyle(color: _C.textPri, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _C.textPri),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loanFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _C.accent));
          }
          if (snap.hasError) {
            return Center(child: Text('Ошибка: ${snap.error}', style: const TextStyle(color: _C.textSec)));
          }

          final loan     = snap.data!['loan'];
          final schedule = snap.data!['schedule'] as List<dynamic>;
          final payments = snap.data!['payments'] as List<dynamic>;

          final amount   = double.tryParse(loan['loan_amount']?.toString() ?? '0') ?? 0;
          final balance  = double.tryParse(loan['principal_balance']?.toString() ?? '0') ?? 0;
          final interest = double.tryParse(loan['accrued_interest']?.toString() ?? '0') ?? 0;
          final penalty  = double.tryParse(loan['accrued_penalty']?.toString() ?? '0') ?? 0;

          return Column(
            children: [
              // Главная карточка
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.surface, _C.card],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('№${loan['contract_number']}', style: const TextStyle(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(loan['full_name'] ?? '', style: const TextStyle(color: _C.textSec, fontSize: 13)),
                          ],
                        ),
                        _StatusBadge(status: loan['status']),
                      ],
                    ),
                    const Divider(color: _C.border, height: 32),
                    Row(
                      children: [
                        _AmountItem(label: 'Выдано', amount: fmt.format(amount), color: _C.textPri),
                        const Spacer(),
                        _AmountItem(label: 'Остаток', amount: fmt.format(balance), color: _C.green),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _AmountItem(label: 'Проценты', amount: fmt.format(interest), color: _C.orange, small: true),
                        const Spacer(),
                        _AmountItem(label: 'Пеня', amount: fmt.format(penalty), color: _C.red, small: true),
                      ],
                    ),
                  ],
                ),
              ),

              // Информация о ставках и датах
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _InfoTile(label: 'Выдан', value: loan['issue_date'] != null ? df.format(DateTime.parse(loan['issue_date'])) : '-'),
                    const SizedBox(width: 12),
                    _InfoTile(label: 'Срок до', value: loan['end_date'] != null ? df.format(DateTime.parse(loan['end_date'])) : '-'),
                    const SizedBox(width: 12),
                    _InfoTile(label: 'Ставка', value: '${loan['interest_rate'] ?? '0'}%'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Вкладки: График и Платежи
              TabBar(
                controller: _tabCtrl,
                indicatorColor: _C.accent,
                labelColor: _C.textPri,
                unselectedLabelColor: _C.textSec,
                tabs: const [
                  Tab(text: 'График'),
                  Tab(text: 'Платежи'),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildScheduleList(schedule, fmt, df),
                    _buildPaymentsList(payments, fmt, df),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleList(List<dynamic> list, NumberFormat fmt, DateFormat df) {
    if (list.isEmpty) return const _EmptyState(message: 'График не сформирован');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i];
        final isPaid = item['is_paid'] == true;
        final date = DateTime.parse(item['payment_date']);
        final isOverdue = !isPaid && date.isBefore(DateTime.now());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isOverdue ? _C.red.withOpacity(0.3) : _C.border),
          ),
          child: Row(
            children: [
              Text('${item['payment_number']}', style: const TextStyle(color: _C.textSec, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(df.format(date), style: TextStyle(color: isOverdue ? _C.red : _C.textPri, fontWeight: FontWeight.w600)),
                    Text('Сумма: ${fmt.format(item['payment_amount'])}', style: const TextStyle(color: _C.textSec, fontSize: 11)),
                  ],
                ),
              ),
              if (isPaid)
                const Icon(Icons.check_circle_rounded, color: _C.green, size: 20)
              else if (isOverdue)
                const Icon(Icons.warning_rounded, color: _C.red, size: 20)
              else
                const Icon(Icons.schedule_rounded, color: _C.textSec, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList(List<dynamic> list, NumberFormat fmt, DateFormat df) {
    if (list.isEmpty) return const _EmptyState(message: 'Платежей еще не было');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.arrow_downward_rounded, color: _C.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fmt.format(double.parse(item['amount'].toString()))} сом', style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.bold)),
                    Text(df.format(DateTime.parse(item['transaction_date'])), style: const TextStyle(color: _C.textSec, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Text(
                  item['description'] ?? 'Пополнение', 
                  style: const TextStyle(color: _C.textSec, fontSize: 10),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label, amount;
  final Color color;
  final bool small;
  const _AmountItem({required this.label, required this.amount, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _C.textSec, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$amount сом', style: TextStyle(color: color, fontSize: small ? 14 : 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'Активен' ? _C.green : (status == 'Просрочен' ? _C.red : _C.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status ?? 'Неизвестно', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: _C.textSec, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, style: const TextStyle(color: _C.textSec, fontSize: 14)));
  }
}
