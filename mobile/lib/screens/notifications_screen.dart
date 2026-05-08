import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = PushNotificationService.getNotificationsHistory();
    // Очищаем счетчик непрочитанных при открытии экрана
    PushNotificationService.clearUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.bg,
        elevation: 0,
        title: const Text('Уведомления', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Очистить всё',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить историю?'),
                  content: const Text('Все уведомления будут удалены безвозвратно.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text('Очистить', style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await PushNotificationService.clearHistory();
                setState(() {
                  _historyFuture = PushNotificationService.getNotificationsHistory();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: pal.textSec.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('Нет новых уведомлений', style: TextStyle(color: pal.textSec)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final time = DateTime.tryParse(item['time'] ?? '') ?? DateTime.now();
              final isPayment = item['data']?['type'] == 'payment_reminder';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isPayment ? Colors.blue : Colors.amber).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPayment ? Icons.credit_card : Icons.notifications,
                        color: isPayment ? Colors.blue : Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? '',
                                  style: TextStyle(color: pal.textPri, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Text(
                                DateFormat('HH:mm, dd.MM').format(time),
                                style: TextStyle(color: pal.textHint, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['body'] ?? '',
                            style: TextStyle(color: pal.textSec, fontSize: 13, height: 1.4),
                          ),
                        ],
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
