import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Обработчик фоновых уведомлений (должен быть top-level функцией)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
  await PushNotificationService.saveNotificationLocally(message);
}

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService
//
// Использование:
//   1. В main.dart вызови PushNotificationService.init(apiService)
//   2. При логине/логауте вызывай registerToken/unregisterToken
// ─────────────────────────────────────────────────────────────────────────────
class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _currentToken;
  static Function(RemoteMessage)? onNotificationClick;
  static final unreadCount = ValueNotifier<int>(0);
  static final chatUnreadCount = ValueNotifier<int>(0);
  static final StreamController<Map<String, dynamic>> chatMessageStream = StreamController.broadcast();

  // ─── Канал уведомлений Android ─────────────────────────────────────────────
  static const _paymentChannel = AndroidNotificationChannel(
    'payment_reminders',
    'Напоминания о платежах',
    description: 'Уведомления о предстоящих платежах по займу',
    importance: Importance.high,
    playSound: true,
  );

  // ─── Инициализация ─────────────────────────────────────────────────────────
  static Future<void> init(ApiService apiService) async {
    // 1. Запрашиваем разрешение у пользователя
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Пользователь отклонил уведомления');
      return;
    }

    // 2. Настраиваем локальные уведомления (для показа когда приложение открыто)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_paymentChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 3. Регистрируем обработчик фоновых сообщений
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Когда приложение ОТКРЫТО и приходит уведомление — показываем сами
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      debugPrint('[FCM Foreground] ${notification.title}: ${notification.body}');
      
      await saveNotificationLocally(message);

      // Если это сообщение чата — обновляем счетчик
      if (message.data['type'] == 'chat' || message.data['sender_type'] != null) {
        refreshChatCount(apiService);
      }

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _paymentChannel.id,
            _paymentChannel.name,
            channelDescription: _paymentChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    // 5. Когда пользователь нажал на уведомление и открыл приложение
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('[FCM] Открыто из уведомления: ${message.data}');
      await saveNotificationLocally(message);
      onNotificationClick?.call(message);
    });

    // 6. Проверяем, было ли приложение открыто по клику на уведомление (если оно было закрыто)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Приложение запущено из уведомления');
      await saveNotificationLocally(initialMessage);
      // Задержка, чтобы роутер успел инициализироваться
      Future.delayed(const Duration(milliseconds: 500), () {
        onNotificationClick?.call(initialMessage);
      });
    }

    // 7. Обновляем токен если он изменился
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Токен обновлён');
      _currentToken = newToken;
      try {
        await apiService.saveFcmToken(newToken);
      } catch (e) {
        debugPrint('[FCM] Ошибка сохранения обновлённого токена: $e');
      }
    });

    // 8. Загружаем начальное количество непрочитанных
    final prefs = await SharedPreferences.getInstance();
    unreadCount.value = prefs.getInt('unread_notifications_count') ?? 0;

    debugPrint('[FCM] Инициализация завершена');
  }

  // ─── Вызывай после успешного логина ────────────────────────────────────────
  static Future<void> registerToken(ApiService apiService) async {
    try {
      // На iOS нужно явно запросить APNs токен
      if (Platform.isIOS) {
        await _messaging.getAPNSToken();
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM] Не удалось получить токен');
        return;
      }

      _currentToken = token;
      debugPrint('[FCM] Токен получен: ${token.substring(0, 20)}...');

      await apiService.saveFcmToken(token);
      debugPrint('[FCM] Токен сохранён на сервере');
    } catch (e) {
      debugPrint('[FCM] Ошибка registerToken: $e');
    }
  }

  // ─── Вызывай при логауте ───────────────────────────────────────────────────
  static Future<void> unregisterToken(ApiService apiService) async {
    if (_currentToken == null) return;
    try {
      await apiService.deleteFcmToken(_currentToken!);
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('[FCM] Токен удалён');
    } catch (e) {
      debugPrint('[FCM] Ошибка unregisterToken: $e');
    }
  }

  static String? get currentToken => _currentToken;

  // ─── Локальное хранилище уведомлений ───────────────────────────────────────
  static Future<void> saveNotificationLocally(RemoteMessage message) async {
    try {
      final id = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notifications_history') ?? [];
      
      // Проверка на дубликаты
      final existingIds = list.map((e) => jsonDecode(e)['id']).toList();
      if (existingIds.contains(id)) {
        debugPrint('[FCM] Уведомление $id уже сохранено');
        return;
      }

      final newItem = {
        'id': id,
        'title': message.notification?.title ?? message.data['title'] ?? 'Уведомление',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'time': DateTime.now().toIso8601String(),
        'data': message.data,
      };

      list.insert(0, jsonEncode(newItem));
      if (list.length > 50) list.removeLast();

      await prefs.setStringList('notifications_history', list);
      
      // Увеличиваем счетчик непрочитанных
      unreadCount.value++;
      await prefs.setInt('unread_notifications_count', unreadCount.value);
      
      debugPrint('[FCM] Уведомление сохранено локально: $id');
    } catch (e) {
      debugPrint('[FCM] Ошибка сохранения уведомления: $e');
    }
  }

  static Future<void> clearUnreadCount() async {
    unreadCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unread_notifications_count', 0);
  }

  static Future<List<Map<String, dynamic>>> getNotificationsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('notifications_history') ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications_history');
  }

  static Future<void> refreshChatCount(ApiService api) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      if (role == null) return;
      
      final contacts = await api.getChatContacts(isStaff: role == 'staff');
      int total = 0;
      for (var c in contacts) {
        total += int.tryParse(c['unread_count']?.toString() ?? '0') ?? 0;
      }
      chatUnreadCount.value = total;
    } catch (e) {
      debugPrint('[FCM] Error refreshing chat count: $e');
    }
  }
}
