import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/payment.dart';

class ScheduleScreen extends StatefulWidget {
  final String loanId;
  const ScheduleScreen({super.key, required this.loanId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _api = ApiService();
  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Payment>> _load() async {
    final data = await _api.getLoanSchedule(widget.loanId);
    return data.map((j) => Payment.fromJson(j as Map<String, dynamic>)).toList();
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
          'График платежей #${widget.loanId}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: FutureBuilder<List<Payment>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Ошибка загрузки', style: TextStyle(color: Colors.white54)));
          }

          final payments = snap.data!;
          final fmt = NumberFormat('#,##0.00', 'ru_RU');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (_, i) {
              final p = payments[i];
              final color = p.isOverdue
                  ? Colors.redAccent
                  : p.isPaid
                      ? Colors.green
                      : const Color(0xFF1A56DB);
              final icon = p.isPaid
                  ? Icons.check_circle_rounded
                  : p.isOverdue
                      ? Icons.warning_rounded
                      : Icons.radio_button_unchecked;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMMM yyyy', 'ru').format(p.paymentDate),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          if (p.isPaid)
                            const Text('Оплачено',
                              style: TextStyle(color: Colors.green, fontSize: 12))
                          else if (p.isOverdue)
                            Text('Просрочено на ${fmt.format(p.totalAmount)} сом',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                          else
                            Text('К оплате ${fmt.format(p.totalAmount)} сом',
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      '${fmt.format(p.totalAmount)} сом',
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
