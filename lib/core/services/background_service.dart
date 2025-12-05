import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
      importance: Importance.low,
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

        // Автостарт false, запускаем вручную при старте приложения
        autoStart: false,
        isForegroundMode: true,

        foregroundServiceTypes: [
          AndroidForegroundType.health,
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
        ],

        notificationChannelId: 'mdd_watch_foreground',
        initialNotificationTitle: 'MDD Watch',
        initialNotificationContent: 'Initializing...',
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
  await Hive.initFlutter();
  // Открываем бокс, так как репозиторий его использует
  await Hive.openBox(AppConstants.settingsBoxName);
  await configureDependencies();

  // Получение зависимостей
  final bleServer = getIt<BleServerService>();
  final fallDetector = getIt<FallDetectionService>();
  final watchRepository = getIt<WatchRepository>();
  final battery = Battery();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 2. Запуск BLE Сервера
  final deviceId = watchRepository.getDeviceId();
  // Передаем ID как имя устройства для рекламы
  await bleServer.startServer(deviceId);

  // 3. Запуск мониторинга падения
  fallDetector.startMonitoring();

  // 4. Держим процессор включенным (WakeLock CPU only)
  // WakelockPlus.enable(); // Убрали, так как это вызывает ошибку в фоне на Android

  print("Background Service: Started for $deviceId");
  _updateNotification(flutterLocalNotificationsPlugin, "Waiting for connection...");

  // --- LISTENERS ---

  // Слушаем события от BLE (из нативного кода)
  bleServer.bleEvents.listen((event) async {

    // 1. Статус подключения
    if (event['type'] == 'connectionState') {
      final state = event['data']['state']; // 'connected' или 'disconnected'
      final isConnected = state == 'connected';

      print("Background: Connection state changed -> $state");

      // Пересылаем событие в UI
      service.invoke('connectionUpdate', {'isConnected': isConnected});

      if (isConnected) {
        _updateNotification(flutterLocalNotificationsPlugin, "Connected to Companion");
      } else {
        _updateNotification(flutterLocalNotificationsPlugin, "Disconnected (Monitoring)");
      }
    }

    // 2. Пришел конфиг (настройки)
    if (event['type'] == 'configReceived') {
      final data = event['data'];
      print("Background: Config received: $data");

      // Сохраняем настройки и помечаем как зарегистрированное
      await watchRepository.setRegistered(true);
      await watchRepository.saveSettings(data['sensitivity'], data['timeout']);

      // Уведомляем UI об изменении статуса регистрации
      service.invoke('refreshStatus', {'isRegistered': true});

      _updateNotification(flutterLocalNotificationsPlugin, "Paired & Monitoring");
    }

    // 3. Пришел ACK (подтверждение получения SOS)
    if (event['type'] == 'ackReceived') {
      bool success = event['data']['success'];
      if (success) {
        print("Background: SOS ACK received!");
        // Уведомляем UI, чтобы закрыть экран тревоги
        service.invoke('sosAck');

        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 200, 100, 200]);
        }
        _updateNotification(flutterLocalNotificationsPlugin, "Help is on the way!");
      }
    }
  });

  // Слушаем падения от сенсоров
  fallDetector.onFallDetected.listen((_) {
    _handleFallDetected(service, bleServer, watchRepository);
  });

  // Слушаем команды от UI
  service.on('cancelSos').listen((event) {
    _cancelSosTimer();
  });

  service.on('simulateFall').listen((event) {
    _handleFallDetected(service, bleServer, watchRepository);
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
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    if (!watchRepository.isRegistered()) return;

    print("Background: Sending Heartbeat...");
    final int batteryLevel = await battery.batteryLevel;

    final payload = {
      "type": "TRACKING",
      "battery": batteryLevel,
      "timestamp": DateTime.now().toIso8601String(),
    };

    bleServer.updateSosCharacteristic(payload);
  });
}

// --- Логика SOS Таймера ---

Timer? _sosTimer;
int _countdown = 30;

void _handleFallDetected(
    ServiceInstance service,
    BleServerService bleServer,
    WatchRepository repo,
    ) async {
  if (!repo.isRegistered()) {
    print("Fall detected but device not registered. Ignoring.");
    return;
  }

  print("Background: Handling Fall...");

  // Уведомляем UI
  service.invoke('showAlarmScreen');

  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(duration: 3000);
  }

  _countdown = repo.getSosTimeout();
  _sosTimer?.cancel();

  _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _countdown--;
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

  if (await Vibration.hasVibrator() ?? false) {
    Vibration.vibrate(duration: 500);
  }

  final battery = Battery();
  final level = await battery.batteryLevel;

  final payload = {
    "type": "FALL_DETECTED",
    "severity": 5,
    "timestamp": DateTime.now().toIso8601String(),
    "battery_level": level,
  };

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