import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class _C {
  static const gold = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const accent = Color(0xFF2563EB);
  static const accentLt = Color(0xFF3B82F6);
}

class ShareDetailsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  const ShareDetailsScreen(
      {super.key, required this.clientId, required this.clientName});

  @override
  State<ShareDetailsScreen> createState() => _ShareDetailsScreenState();
}

class _ShareDetailsScreenState extends State<ShareDetailsScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _api.getClientShareHistory(widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        elevation: 0,
        title: Text('История паёв',
            style: TextStyle(
                color: pal.textPri, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: pal.textPri),
      ),
      body: Column(
        children: [
          // Шапка с ФИО
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Заёмщик',
                    style: TextStyle(color: pal.textSec, fontSize: 11)),
                const SizedBox(height: 4),
                Text(widget.clientName,
                    style: TextStyle(
                        color: pal.textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _historyFuture,
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

                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                      child: Text('Операций по паям еще не было',
                          style: TextStyle(color: pal.textSec)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final item = list[i];
                    final type = item['transaction_type'] ?? '';
                    final amount =
                        double.tryParse(item['amount']?.toString() ?? '0') ?? 0;

                    IconData icon;
                    Color color;
                    String label;

                    if (type == 'SHARE_DEPOSIT' || type == 'Паи') {
                      icon = Icons.add_circle_outline_rounded;
                      color = _C.green;
                      label = 'Пополнение пая';
                    } else if (type == 'SHARE_WITHDRAW') {
                      icon = Icons.remove_circle_outline_rounded;
                      color = _C.orange;
                      label = 'Вывод пая';
                    } else if (type == 'DIVIDEND_PAYOUT') {
                      icon = Icons.star_border_rounded;
                      color = _C.gold;
                      label = 'Начисление дивидендов';
                    } else {
                      icon = Icons.sync_alt_rounded;
                      color = pal.textSec;
                      label = item['description'] ?? 'Операция';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: TextStyle(
                                        color: pal.textPri,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    df.format(DateTime.parse(
                                        item['transaction_date'])),
                                    style: TextStyle(
                                        color: pal.textSec, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            '${amount > 0 ? '+' : ''}${fmt.format(amount)}',
                            style: TextStyle(
                                color: amount > 0 ? _C.green : pal.textPri,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
