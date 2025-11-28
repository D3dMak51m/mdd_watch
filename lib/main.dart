import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/injection.dart'; // Создадим позже

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Часы обычно имеют маленькие экраны, фиксируем ориентацию
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Инициализация DI (пока закомментировано, так как файл еще не создан)
  // await configureDependencies();

  runApp(const MddWatchApp());
}

class MddWatchApp extends StatelessWidget {
  const MddWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDD Watch',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark, // Для часов лучше темная тема (экономия энергии)
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('MDD Watch Initialized')),
      ),
    );
  }
}