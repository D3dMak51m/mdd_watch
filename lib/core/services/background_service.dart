import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:vibration/vibration.dart'; // Добавьте в pubspec.yaml
import 'package:wakelock_plus/wakelock_plus.dart';

import '../di/injection.dart'; // Предполагаем, что DI настроен
import 'ble_server_service.dart';
import 'fall_detection_service.dart';

@lazySingleton
class AppBackgroundService {
  // ... (код initialize, startService, stopService из предыдущих шагов) ...
  // Убедитесь, что в initialize() -> androidConfiguration -> onStart: onStart
}

// --- ENTRY POINT ---

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Инициализация DI в изоляте
  await configureDependencies();

  final bleServer = getIt<BleServerService>();
  final fallDetector = getIt<FallDetectionService>();

  // Для уведомлений
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 1. Запускаем BLE Сервер
  await bleServer.startServer();

  // 2. Запускаем мониторинг падения
  fallDetector.startMonitoring();

  // Держим процессор включенным
  WakelockPlus.enable();

  // Слушаем падения
  fallDetector.onFallDetected.listen((_) {
    _handleFallDetected(service, bleServer);
  });

  // Слушаем команды от UI (например, отмена тревоги)
  service.on('cancelSos').listen((event) {
    _cancelSosTimer();
  });

  // Слушаем события от BLE (например, пришел ACK от телефона)
  bleServer.bleEvents.listen((event) {
    if (event['type'] == 'ackReceived') {
      bool success = event['data']['success'];
      if (success) {
        _showNotification(flutterLocalNotificationsPlugin, "Help is on the way!");
        // Можно попищать/повибрировать иначе
      }
    }
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
}

// --- Логика SOS Таймера ---

Timer? _sosTimer;
int _countdown = 30; // Секунд до отправки

void _handleFallDetected(ServiceInstance service, BleServerService bleServer) async {
  print("Background: Handling Fall...");

  // 1. Уведомляем UI, чтобы показать экран тревоги
  service.invoke('showAlarmScreen');

  // 2. Вибрация (SOS pattern)
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 1); // Пищим пока не отменят (repeat 1 - loop? check docs)
    // Для простоты: просто долгая вибрация
    Vibration.vibrate(duration: 3000);
  }

  // 3. Запускаем таймер
  _countdown = 30;
  _sosTimer?.cancel();
  _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _countdown--;

    // Шлем тик таймера в UI
    service.invoke('timerTick', {'seconds': _countdown});

    if (_countdown <= 0) {
      _sendSos(bleServer);
      timer.cancel();
    }
  });
}

void _cancelSosTimer() {
  print("Background: SOS Cancelled by user");
  _sosTimer?.cancel();
  Vibration.cancel();
}

void _sendSos(BleServerService bleServer) {
  print("Background: Sending SOS...");
  Vibration.vibrate(duration: 500); // Короткий пик "Отправлено"

  // Формируем Payload
  final payload = {
    "type": "FALL_DETECTED",
    "severity": 5,
    "timestamp": DateTime.now().toIso8601String(),
    "battery_level": 80, // TODO: Get real battery
  };

  // Отправляем через BLE (обновляем характеристику)
  // Телефон (Компаньон) увидит изменение и отправит на сервер
  bleServer.updateSosCharacteristic(payload);

  // TODO: Если BLE не подключен (проверить статус), пытаться слать через HTTP напрямую
}

void _showNotification(FlutterLocalNotificationsPlugin plugin, String text) {
  // ... код показа уведомления ...
}