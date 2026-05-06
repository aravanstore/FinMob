import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _visitsFuture;

  @override
  void initState() {
    super.initState();
    _visitsFuture = _api.getVisits();
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть карту')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final df = DateFormat('dd.MM.yy HH:mm');

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        title: Text('Карта визитов (за сегодня)', style: TextStyle(color: pal.textPri)),
        iconTheme: IconThemeData(color: pal.textPri),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _visitsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: pal.accent));
          }
          if (snap.hasError) {
            return Center(child: Text('Ошибка: ${snap.error}', style: TextStyle(color: pal.textSec)));
          }

          final visits = snap.data ?? [];
          if (visits.isEmpty) {
            return Center(child: Text('За сегодня визитов не было', style: TextStyle(color: pal.textHint)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (ctx, i) {
              final v = visits[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            v['client_name'] ?? 'Клиент ID: ${v['client_id']}',
                            style: TextStyle(color: pal.textPri, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Text(
                          df.format(DateTime.parse(v['created_at']).toLocal()),
                          style: TextStyle(color: pal.textSec, fontSize: 12),
                        ),
                      ],
                    ),
                    if (v['notes'] != null && v['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(v['notes'], style: TextStyle(color: pal.textSec, fontSize: 14)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openMap(
                          double.parse(v['latitude'].toString()), 
                          double.parse(v['longitude'].toString())
                        ),
                        icon: Icon(Icons.map, color: pal.accent),
                        label: Text('Показать на карте', style: TextStyle(color: pal.accent)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: pal.accent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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
