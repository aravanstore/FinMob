import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailsScreen({super.key, required this.clientId});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _api.getClientDetails(widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Профиль клиента',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Ошибка: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white54)));
          }

          final data = snapshot.data!;
          final client = data['client'];
          final loans = data['loans'] as List<dynamic>;
          final summary = data['summary'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Карточка клиента
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client['full_name'] ?? 'Без имени',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _infoRow(Icons.phone, client['phone_main'] ?? '-'),
                    _infoRow(Icons.badge, 'ИНН: ${client['inn'] ?? '-'}'),
                    _infoRow(
                        Icons.location_on, client['address_factual'] ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Сводка
              const Text('Сводка по кредитам',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryItem(
                      'Всего', '${summary['total_loans']}', Colors.blue),
                  const SizedBox(width: 12),
                  _summaryItem(
                      'Активных', '${summary['active_loans']}', Colors.green),
                  const SizedBox(width: 12),
                  _summaryItem('Просрочено', '${summary['overdue_count']}',
                      Colors.redAccent),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Паи и дивиденды',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryItem(
                      'Баланс паёв (сом)',
                      fmt.format(double.parse(
                          (client['share_balance'] ?? 0).toString())),
                      Colors.orange),
                  const SizedBox(width: 12),
                  _summaryItem(
                      'Дивиденды (сом)',
                      fmt.format(double.parse(
                          (client['accrued_dividends'] ?? 0).toString())),
                      Colors.amber),
                ],
              ),
              const SizedBox(height: 20),

              // Список кредитов
              const Text('Кредиты',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (loans.isEmpty)
                const Center(
                    child: Text('Кредитов не найдено',
                        style: TextStyle(color: Colors.white38)))
              else
                ...loans.map((l) => _loanTile(l, fmt)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _loanTile(dynamic l, NumberFormat fmt) {
    final status = l['calculated_status'] ?? l['status'];
    final color = status == 'Просрочен'
        ? Colors.redAccent
        : (status == 'Активен' ? Colors.blue : Colors.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('№${l['contract_number']}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(status,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${fmt.format(double.parse(l['principal_balance'].toString()))} сом',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Text('Остаток основного долга',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
