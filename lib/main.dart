import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'presentation/screens/splash_screen.dart'; // Создадим позже

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.settingsBox);
  await Hive.openBox(AppConstants.appBox);

  // Init DI
  await configureDependencies();

  runApp(const MddWatchApp());
}

class MddWatchApp extends StatelessWidget {
  const MddWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDD Watch',
      theme: ThemeData(
        brightness: Brightness.dark, // Часы обычно используют темную тему для экономии
        primarySwatch: Colors.red,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),
    );
  }
}