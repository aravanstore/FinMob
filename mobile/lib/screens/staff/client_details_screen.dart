import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';

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
    final pal = AppPalette.of(context);
    final fmt = NumberFormat('#,##0.00', 'ru_RU');

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        title: Text('Профиль клиента', style: TextStyle(color: pal.textPri)),
        iconTheme: IconThemeData(color: pal.textPri),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: pal.accent));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Ошибка: ${snapshot.error}',
                    style: TextStyle(color: pal.textSec)));
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
                  color: pal.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client['full_name'] ?? 'Без имени',
                        style: TextStyle(
                            color: pal.textPri,
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
              Text('Сводка по кредитам',
                  style: TextStyle(
                      color: pal.textSec,
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
              Text('Паи и дивиденды',
                  style: TextStyle(
                      color: pal.textSec,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push(
                    '/staff/client/${widget.clientId}/shares',
                    extra: {'name': client['full_name']}),
                child: Row(
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
              ),
              const SizedBox(height: 20),

              // Список кредитов
              Text('Кредиты',
                  style: TextStyle(
                      color: pal.textSec,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (loans.isEmpty)
                Center(
                    child: Text('Кредитов не найдено',
                        style: TextStyle(color: pal.textHint)))
              else
                ...loans.map((l) => GestureDetector(
                      onTap: () => context.push('/staff/loan/${l['loan_id']}'),
                      child: _loanTile(l, fmt),
                    )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logVisit,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Отметить визит', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _logVisit() async {
    final pal = AppPalette.of(context);
    final ctrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.bg,
        title: Text('Отметка визита', style: TextStyle(color: pal.textPri)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ваши текущие GPS-координаты будут прикреплены к отчету автоматически.', style: TextStyle(color: pal.textSec, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: TextStyle(color: pal.textPri),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Результат встречи / комментарий',
                hintStyle: TextStyle(color: pal.textHint),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: pal.border)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2563EB))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (res != true) return;

    // GPS Loading Dialog
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS выключен. Включите геолокацию.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Доступ к геолокации запрещен.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Доступ к геолокации запрещен навсегда. Разрешите в настройках.');
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      await _api.logVisit(int.parse(widget.clientId), position.latitude, position.longitude, ctrl.text);
      
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Визит успешно сохранен'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Widget _infoRow(IconData icon, String text) {
    final pal = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: pal.textHint),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: pal.textSec, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    final pal = AppPalette.of(context);
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
            Text(label, style: TextStyle(color: pal.textHint, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _loanTile(dynamic l, NumberFormat fmt) {
    final pal = AppPalette.of(context);
    final status = l['calculated_status'] ?? l['status'];
    final color = status == 'Просрочен'
        ? Colors.redAccent
        : (status == 'Активен' ? Colors.blue : Colors.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
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
                  style: TextStyle(
                      color: pal.textPri, fontWeight: FontWeight.bold)),
              Text(status,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${fmt.format(double.parse(l['principal_balance'].toString()))} сом',
              style: TextStyle(
                  color: pal.textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('Остаток основного долга',
              style: TextStyle(color: pal.textHint, fontSize: 11)),
        ],
      ),
    );
  }
}
