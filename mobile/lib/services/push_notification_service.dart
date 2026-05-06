import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Обработчик фоновых уведомлений (должен быть top-level функцией)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Уведомление пришло пока приложение закрыто — Android покажет его сам
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      debugPrint('[FCM Foreground] ${notification.title}: ${notification.body}');

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
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Открыто из уведомления: ${message.data}');
      // Здесь можно добавить навигацию, например:
      // if (message.data['type'] == 'payment_reminder') { ... }
    });

    // 6. Обновляем токен если он изменился
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Токен обновлён');
      _currentToken = newToken;
      try {
        await apiService.saveFcmToken(newToken);
      } catch (e) {
        debugPrint('[FCM] Ошибка сохранения обновлённого токена: $e');
      }
    });

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
}
