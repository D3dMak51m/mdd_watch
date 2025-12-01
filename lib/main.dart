import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/di/injection.dart';
import 'core/services/background_service.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/alarm_screen.dart';

// Глобальный ключ навигации для открытия экранов из фона
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Перехват ошибок зоны
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Фиксация ориентации (для часов обычно портретная)
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

      // 2. Держим экран включенным (опционально, зависит от требований к батарее)
      // WakelockPlus.enable();

      // 3. Инициализация DI
      await configureDependencies();

      // 4. Запрос разрешений (Критично для Android 10+)
      await _requestPermissions();

      // 5. Инициализация и старт фонового сервиса
      final bgService = getIt<AppBackgroundService>();
      await bgService.initialize();
      await bgService.startService();

      runApp(const MddWatchApp());
    },
    (error, stack) {
      print("Global Error: $error");
      print(stack);
    },
  );
}

Future<void> _requestPermissions() async {
  // Запрашиваем все необходимые разрешения разом
  await [
    Permission.location, // Нужен для BLE и GPS
    Permission.bluetooth,
    Permission.bluetoothAdvertise, // Android 12+
    Permission.bluetoothConnect, // Android 12+
    Permission.sensors, // Акселерометр
    Permission.notification, // Foreground Service
    Permission.ignoreBatteryOptimizations, // Чтобы система не убивала сервис
  ].request();
}

class MddWatchApp extends StatefulWidget {
  const MddWatchApp({super.key});

  @override
  State<MddWatchApp> createState() => _MddWatchAppState();
}

class _MddWatchAppState extends State<MddWatchApp> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Слушаем команду на открытие экрана тревоги от фонового сервиса
    FlutterBackgroundService().on('showAlarmScreen').listen((event) {
      // Проверяем, может экран уже открыт
      // Используем pushAndRemoveUntil или просто push
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const AlarmScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MDD Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark, // Темная тема экономит батарею на OLED
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}
