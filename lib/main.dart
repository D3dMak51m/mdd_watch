import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/services/background_service.dart';
import 'presentation/screens/alarm_screen.dart';
import 'presentation/screens/home_screen.dart'; // Этот экран создадим на следующем шаге

// Глобальный ключ навигации для управления переходами из фоновых событий
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Используем runZonedGuarded для перехвата ошибок, которые могут "уронить" приложение
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Фиксация ориентации (для часов обычно только портрет)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 2. Инициализация Hive (Локальная БД)
    await Hive.initFlutter();
    // Открываем боксы для настроек и данных пользователя
    await Hive.openBox(AppConstants.settingsBoxName);
    // Если используете отдельный бокс для состояния регистрации:
    // await Hive.openBox(AppConstants.userBoxName);

    // 3. Инициализация DI (GetIt)
    await configureDependencies();

    // 4. Инициализация и запуск фонового сервиса
    // Это критически важно сделать до запуска UI, чтобы сервис начал работу
    final bgService = getIt<AppBackgroundService>();
    await bgService.initialize();
    await bgService.startService();

    runApp(const MddWatchApp());
  }, (error, stack) {
    print("Global Error: $error");
    print(stack);
  });
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
    _setupGlobalListeners();
  }

  /// Слушатели событий от фонового сервиса
  void _setupGlobalListeners() {
    // Слушаем событие обнаружения падения
    FlutterBackgroundService().on('showAlarmScreen').listen((event) {
      print("UI: Received showAlarmScreen event");

      // Проверяем, может быть мы уже на экране тревоги, чтобы не открывать дубликаты
      // (В простой реализации просто пушим сверху)
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AlarmScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Обязательно подключаем ключ
      title: 'MDD Watch',
      debugShowCheckedModeBanner: false,

      // Тема для часов: Темная, контрастная, экономичная (OLED)
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,

        // Настройка текста для маленьких экранов
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),

      // Стартовый экран (реализуем на следующем шаге)
      home: const HomeScreen(),
    );
  }
}