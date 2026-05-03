import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final String loanId;
  const HistoryScreen({super.key, required this.loanId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getLoanTransactions(widget.loanId);
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'client.history_title'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snap.hasError) {
            return Center(
              child: Text('client.error_loading'.tr(), style: const TextStyle(color: Colors.white54)));
          }

          final transactions = snap.data!;
          if (transactions.isEmpty) {
            return Center(
              child: Text('client.no_history'.tr(), style: const TextStyle(color: Colors.white38)));
          }

          final fmt = NumberFormat('#,##0.00', 'ru_RU');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (_, i) {
              final t = transactions[i];
              final isPayment = t['transaction_type'] == 'payment' || t['transaction_type'] == 'Оплата' || t['transaction_type'] == 'repayment';
              final color = isPayment ? Colors.green : Colors.white70;
              final icon = isPayment ? Icons.arrow_downward : Icons.swap_horiz;
              final amount = _d(t['amount']);
              final dateStr = t['transaction_date'] ?? '';
              final DateTime date = DateTime.tryParse(dateStr) ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['description']?.toString() ?? 'client.operation'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal()),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPayment ? '+' : ''}${fmt.format(amount)} ${'client.currency'.tr()}',
                      style: TextStyle(
                        color: color, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
