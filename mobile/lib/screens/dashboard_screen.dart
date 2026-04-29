import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/loan.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  late Future<List<Loan>> _loansFuture;
  late Future<Map<String, dynamic>> _sharesFuture;

  @override
  void initState() {
    super.initState();
    _loansFuture = _loadLoans();
    _sharesFuture = _api.getSharesSummary();
  }

  Future<List<Loan>> _loadLoans() async {
    final data = await _api.getLoans();
    return data.map((j) => Loan.fromJson(j as Map<String, dynamic>)).toList();
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Мои кредиты',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            Text(auth.phone,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Loan>>(
        future: _loansFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snap.hasError) {
            print("Dashboard _loadLoans Error: ${snap.error}");
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white30, size: 64),
                  const SizedBox(height: 16),
                  const Text('Нет соединения с сервером',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _loansFuture = _loadLoans();
                      _sharesFuture = _api.getSharesSummary();
                    }),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final loans = snap.data!;

          return RefreshIndicator(
            onRefresh: () async => setState(() {
              _loansFuture = _loadLoans();
              _sharesFuture = _api.getSharesSummary();
            }),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _sharesFuture,
                  builder: (context, shareSnap) {
                    if (shareSnap.hasError) {
                      print("Dashboard Shares Error: ${shareSnap.error}");
                      return const SizedBox.shrink();
                    }
                    if (shareSnap.hasData) {
                      final s = shareSnap.data!;
                      return _SharesCard(
                        shares:    _d(s['share_balance']),
                        dividends: _d(s['accrued_dividends']),
                        fmt: fmt,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 20),
                const Text('Мои кредиты',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (loans.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('Кредитов не найдено',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  ...loans.map((l) => _LoanCard(loan: l, fmt: fmt)).toList(),
              ],
            ),
          );
        },
      ),
      // Кнопка QR оплаты
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/payments'),
        backgroundColor: const Color(0xFF1A56DB),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Оплатить', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final NumberFormat fmt;
  const _LoanCard({required this.loan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = loan.isOverdue
        ? Colors.redAccent
        : loan.isActive
            ? const Color(0xFF1A56DB)
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Кредит №${loan.contractNumber}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  loan.isOverdue
                      ? 'Просрочен'
                      : loan.isActive
                          ? 'Активен'
                          : 'Закрыт',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Основной долг
          Text(
            '${fmt.format(loan.totalDebt)} сом',
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text('Остаток основного долга',
              style: TextStyle(color: Colors.white38, fontSize: 12)),

          const SizedBox(height: 16),

          // Детали: полное погашение, ставка, даты
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _infoRow('Полное погашение:',
                    '${fmt.format(loan.fullRepayment)} сом',
                    isBold: true, color: Colors.greenAccent),
                const SizedBox(height: 6),
                _infoRow('Просрочено (штрафы/%):',
                    '${fmt.format(loan.totalOverdue)} сом',
                    color: loan.totalOverdue > 0
                        ? Colors.redAccent
                        : Colors.white70),
                const SizedBox(height: 6),
                _infoRow('Начисленные %:',
                    '${fmt.format(loan.accruedInterest)} сом'),
                const Divider(color: Colors.white12, height: 16),
                _infoRow('Процентная ставка:', '${loan.interestRate}% годовых'),
                const SizedBox(height: 6),
                _infoRow('Срок кредита:',
                    '${DateFormat('dd.MM.yy').format(loan.issueDate)} — ${DateFormat('dd.MM.yy').format(loan.endDate)}'),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Прогресс-бар
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: loan.paidPercent,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Выплачено ${(loan.paidPercent * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),

          const SizedBox(height: 16),
          // Кнопки действий
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/schedule/${loan.id}'),
                  icon: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
                  label: const Text('График', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/history/${loan.id}'),
                  icon: const Icon(Icons.history, size: 16, color: Colors.white),
                  label: const Text('История', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool isBold = false, Color color = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }
}

class _SharesCard extends StatelessWidget {
  final double shares;
  final double dividends;
  final NumberFormat fmt;

  const _SharesCard({
    required this.shares,
    required this.dividends,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Паи и Дивиденды',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statColumn(
                    'Мои паи', '${fmt.format(shares)} сом', Colors.blueAccent),
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(
                child: _statColumn('Дивиденды', '${fmt.format(dividends)} сом',
                    Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/shares-history'),
              icon: const Icon(Icons.history, size: 16, color: Colors.white),
              label: const Text('История операций', 
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: Colors.blueAccent.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
