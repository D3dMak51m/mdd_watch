import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants/app_constants.dart';
import '../di/injection.dart';
import 'ble_server_service.dart';
import 'fall_detection_service.dart';
import '../../data/repositories/watch_repository.dart';

@lazySingleton
class AppBackgroundService {
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Настройка канала уведомлений для Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mdd_watch_foreground', // id
      'MDD Watch Monitoring', // title
      description: 'Monitoring fall detection and connection',
      importance: Importance.low, // Low, чтобы не было звука при обновлении уведомления
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Эта функция выполняется в отдельном изоляте
        onStart: onStart,

        // Автостарт false, так как мы запускаем сервис вручную при старте приложения
        autoStart: false,
        isForegroundMode: true,

        // Критически важно для Android 14+
        // health - для доступа к BODY_SENSORS в фоне
        // connectedDevice - для работы Bluetooth
        foregroundServiceTypes: [
          AndroidForegroundType.health,
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],

        notificationChannelId: 'mdd_watch_foreground',
        initialNotificationTitle: 'MDD Watch',
        initialNotificationContent: 'Monitoring Active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }
}

// --- ENTRY POINTS (Выполняются в изоляте) ---

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // 1. Инициализация DI в изоляте
  await configureDependencies();

  // Получение зависимостей
  final bleServer = getIt<BleServerService>();
  final fallDetector = getIt<FallDetectionService>();
  final watchRepository = getIt<WatchRepository>();
  final battery = Battery();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 2. Запуск BLE Сервера (реклама устройства)
  await bleServer.startServer();

  // 3. Запуск мониторинга падения
  // Здесь можно передать чувствительность из настроек
  // fallDetector.setSensitivity(watchRepository.getSensitivity());
  fallDetector.startMonitoring();

  // 4. Держим процессор включенным (WakeLock)
  WakelockPlus.enable();

  print("Background Service: Started");

  // --- LISTENERS ---

  // Слушаем падения от сенсоров
  fallDetector.onFallDetected.listen((_) {
    _handleFallDetected(service, bleServer, watchRepository);
  });

  // Слушаем команды от UI (нажатие кнопки "Я в порядке")
  service.on('cancelSos').listen((event) {
    _cancelSosTimer();
  });

  // Слушаем ручной вызов SOS (долгое нажатие кнопки в UI)
  service.on('simulateFall').listen((event) {
    _handleFallDetected(service, bleServer, watchRepository);
  });

  // Слушаем события от BLE (пришли данные от телефона)
  bleServer.bleEvents.listen((event) {

    // Пришел конфиг (настройки)
    if (event['type'] == 'configReceived') {
      final data = event['data'];
      print("Background: Config received: $data");

      // Сохраняем настройки и помечаем как зарегистрированное
      watchRepository.setRegistered(true);
      watchRepository.saveSettings(data['sensitivity'], data['timeout']);

      // Уведомляем UI, чтобы обновить экран (убрать QR код)
      service.invoke('refreshStatus');

      // Обновляем уведомление
      _updateNotification(flutterLocalNotificationsPlugin, "Paired & Monitoring");
    }

    // Пришел ACK (подтверждение получения SOS)
    if (event['type'] == 'ackReceived') {
      bool success = event['data']['success'];
      if (success) {
        print("Background: SOS ACK received!");
        // Вибрация успеха (два коротких)
        if (Vibration.hasVibrator() != null) {
          Vibration.vibrate(pattern: [0, 200, 100, 200]);
        }
        _updateNotification(flutterLocalNotificationsPlugin, "Help is on the way!");
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

  // --- PERIODIC TRACKING (Heartbeat) ---
  // Каждые 15 минут отправляем заряд батареи
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    if (!watchRepository.isRegistered()) return;

    print("Background: Sending Heartbeat...");
    final int batteryLevel = await battery.batteryLevel;

    final payload = {
      "type": "TRACKING",
      "battery": batteryLevel,
      "timestamp": DateTime.now().toIso8601String(),
    };

    // Отправляем на телефон через BLE
    bleServer.updateSosCharacteristic(payload);
  });
}

// --- Логика SOS Таймера ---

Timer? _sosTimer;
int _countdown = 30;

void _handleFallDetected(
    ServiceInstance service,
    BleServerService bleServer,
    WatchRepository repo
    ) async {
  if (!repo.isRegistered()) {
    print("Fall detected but device not registered. Ignoring.");
    return;
  }

  print("Background: Handling Fall...");

  // 1. Уведомляем UI, чтобы показать экран тревоги поверх всего
  service.invoke('showAlarmScreen');

  // 2. Вибрация (SOS pattern)
  if (await Vibration.hasVibrator() ?? false) {
    // Долгая вибрация для привлечения внимания
    Vibration.vibrate(duration: 3000);
  }

  // 3. Запускаем таймер обратного отсчета
  _countdown = repo.getSosTimeout(); // Берем из настроек
  _sosTimer?.cancel();

  _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _countdown--;

    // Шлем тик таймера в UI для обновления цифр
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

void _sendSos(BleServerService bleServer) async {
  print("Background: Sending SOS...");

  // Короткий вибро-отклик "Отправлено"
  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(duration: 500);
  }

  final battery = Battery();
  final level = await battery.batteryLevel;

  // Формируем Payload
  final payload = {
    "type": "FALL_DETECTED",
    "severity": 5, // Можно вычислять динамически на основе силы удара
    "timestamp": DateTime.now().toIso8601String(),
    "battery_level": level,
  };

  // Обновляем характеристику. Телефон (Компаньон) получит уведомление.
  bleServer.updateSosCharacteristic(payload);
}

void _updateNotification(FlutterLocalNotificationsPlugin plugin, String content) {
  plugin.show(
    888,
    'MDD Watch',
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'mdd_watch_foreground',
        'MDD Watch Monitoring',
        icon: '@mipmap/ic_launcher',
        ongoing: true,
        importance: Importance.low,
      ),
    ),
  );
}