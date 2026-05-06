import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';

class _C {
  static const gold = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const accent = Color(0xFF2563EB);
  static const accentLt = Color(0xFF3B82F6);
}

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen>
    with SingleTickerProviderStateMixin {
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
    final pal = AppPalette.of(context);
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        elevation: 0,
        title: Text('Детали кредита',
            style: TextStyle(
                color: pal.textPri, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: pal.textPri),
        actions: [
          IconButton(
            tooltip: 'Тема',
            icon: Icon(
              context.watch<ThemeController>().isLight
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: pal.textSec,
              size: 22,
            ),
            onPressed: () => context.read<ThemeController>().toggle(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loanFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _C.accent));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Ошибка: ${snap.error}',
                    style: TextStyle(color: pal.textSec)));
          }

          final loan =
              snap.data!['loan'] as Map<String, dynamic>? ?? snap.data!;
          final schedule = (snap.data!['schedule'] as List<dynamic>?) ?? [];
          final payments = (snap.data!['payments'] as List<dynamic>?) ?? [];
          final board = loan['board'] as Map<String, dynamic>?;

          double d(String key) =>
              double.tryParse((loan[key] ?? 0).toString()) ?? 0;
          double b(String key) =>
              double.tryParse((board?[key] ?? 0).toString()) ?? 0;

          final amount = d('loan_amount');
          final balance =
              b('balance_od') > 0 ? b('balance_od') : d('principal_balance');
          final interestRate =
              loan['interest_rate_annual'] ?? loan['interest_rate'] ?? '0';

          // Берём данные из board (расчётные) если есть, иначе — из сырых полей
          final overdueOd = b('od_col1_overdue');
          final eomOd = b('od_col2_scheduled');
          final fullOd = b('od_col3_full') > 0 ? b('od_col3_full') : balance;

          final overdueInt = b('int_col1');
          final eomInt = b('int_col2');
          final fullInt = b('int_col3');

          final overduePen = b('pen_col1');
          final eomPen = b('pen_col2');
          final fullPen = b('pen_col3');

          return Column(
            children: [
              // Главная карточка
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pal.surface, pal.card],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pal.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('КД-${loan['contract_number']}',
                                style: TextStyle(
                                    color: pal.textPri,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(loan['full_name'] ?? '',
                                style: TextStyle(
                                    color: pal.textSec, fontSize: 13)),
                          ],
                        ),
                        _StatusBadge(status: loan['status']),
                      ],
                    ),
                    Divider(color: pal.border, height: 24),

                    // Информационное табло как в AURUM
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pal.bg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pal.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Информационное табло',
                              style: TextStyle(
                                  color: pal.textSec,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text('НАИМЕНОВАНИЕ',
                                      style: TextStyle(
                                          color: pal.textHint, fontSize: 10))),
                              Expanded(
                                  flex: 2,
                                  child: Text('ПРОСРОЧКА',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: pal.textHint, fontSize: 10))),
                              Expanded(
                                  flex: 2,
                                  child: Text('К КОНЦУ МЕС.',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: pal.textHint, fontSize: 10))),
                              Expanded(
                                  flex: 2,
                                  child: Text('ПОЛНОЕ',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          color: pal.textHint, fontSize: 10))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTableRow(
                              'ОД', overdueOd, eomOd, fullOd, fmt, pal),
                          _buildTableRow('Проценты', overdueInt, eomInt,
                              fullInt, fmt, pal),
                          _buildTableRow(
                              'Пени', overduePen, eomPen, fullPen, fmt, pal),
                          Divider(color: pal.border, height: 16),
                          _buildTableRow(
                              'ИТОГО',
                              overdueOd + overdueInt + overduePen,
                              eomOd + eomInt + eomPen,
                              fullOd + fullInt + fullPen,
                              fmt,
                              pal,
                              isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Подробности: Выдано, Срок и т.д.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _InfoTile(label: 'Выдано', value: fmt.format(amount)),
                    const SizedBox(width: 12),
                    _InfoTile(
                        label: 'Окончание',
                        value: loan['end_date'] != null
                            ? df.format(DateTime.parse(loan['end_date']))
                            : '-'),
                    const SizedBox(width: 12),
                    _InfoTile(label: 'Ставка', value: '$interestRate%'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Вкладки: График и Платежи
              TabBar(
                controller: _tabCtrl,
                indicatorColor: _C.accent,
                labelColor: pal.textPri,
                unselectedLabelColor: pal.textSec,
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

  Widget _buildTableRow(String label, double v1, double v2, double v3,
      NumberFormat fmt, AppPalette pal,
      {bool isBold = false}) {
    final style = TextStyle(
        color: isBold ? pal.textPri : pal.textSec,
        fontSize: 12,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: style)),
          Expanded(
              flex: 2,
              child: Text(fmt.format(v1),
                  textAlign: TextAlign.right,
                  style: style.copyWith(
                      color: v1 > 0 && label == 'ПРОСРОЧКА'
                          ? Colors.redAccent
                          : style.color))),
          Expanded(
              flex: 2,
              child: Text(fmt.format(v2),
                  textAlign: TextAlign.right, style: style)),
          Expanded(
              flex: 2,
              child: Text(fmt.format(v3),
                  textAlign: TextAlign.right,
                  style: style.copyWith(
                      color: isBold ? Colors.greenAccent : style.color))),
        ],
      ),
    );
  }

  Widget _buildScheduleList(
      List<dynamic> list, NumberFormat fmt, DateFormat df) {
    final pal = AppPalette.of(context);
    if (list.isEmpty)
      return const _EmptyState(message: 'График не сформирован');
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
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOverdue ? _C.red.withValues(alpha: 0.3) : pal.border),
          ),
          child: Row(
            children: [
              Text('${item['payment_number']}',
                  style: TextStyle(
                      color: pal.textSec, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(df.format(date),
                        style: TextStyle(
                            color: isOverdue ? _C.red : pal.textPri,
                            fontWeight: FontWeight.w600)),
                    Text('Сумма: ${fmt.format(item['payment_amount'])}',
                        style: TextStyle(color: pal.textSec, fontSize: 11)),
                  ],
                ),
              ),
              if (isPaid)
                const Icon(Icons.check_circle_rounded,
                    color: _C.green, size: 20)
              else if (isOverdue)
                const Icon(Icons.warning_rounded, color: _C.red, size: 20)
              else
                Icon(Icons.schedule_rounded, color: pal.textSec, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList(
      List<dynamic> list, NumberFormat fmt, DateFormat df) {
    final pal = AppPalette.of(context);
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
            color: pal.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.arrow_downward_rounded,
                  color: _C.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${fmt.format(double.parse(item['amount'].toString()))} сом',
                        style: TextStyle(
                            color: pal.textPri, fontWeight: FontWeight.bold)),
                    Text(df.format(DateTime.parse(item['transaction_date'])),
                        style: TextStyle(color: pal.textSec, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Text(
                  item['description'] ?? 'Пополнение',
                  style: TextStyle(color: pal.textSec, fontSize: 10),
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
  const _AmountItem(
      {required this.label, required this.amount, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: pal.textSec, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$amount сом',
            style: TextStyle(
                color: color,
                fontSize: small ? 14 : 17,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final color = status == 'Активен'
        ? _C.green
        : (status == 'Просрочен' ? _C.red : _C.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status ?? 'Неизвестно',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border)),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: pal.textSec, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: pal.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
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
    final pal = AppPalette.of(context);
    return Center(
        child:
            Text(message, style: TextStyle(color: pal.textSec, fontSize: 14)));
  }
}
