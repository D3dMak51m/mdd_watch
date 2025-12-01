import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mdd_watch/data/repositories/watch_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/di/injection.dart';
import '../bloc/home/home_cubit.dart';
import 'alarm_screen.dart'; // Для ручного теста

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Слушаем обновление статуса от фонового сервиса (например, когда прошла привязка)
    FlutterBackgroundService().on('refreshStatus').listen((_) {
      getIt<HomeCubit>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HomeCubit>(),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              if (state is HomeUnregistered) {
                return _buildPairingView(state.deviceId);
              } else if (state is HomeRegistered) {
                return _buildActiveView(context, state.deviceId);
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  // Экран привязки (QR)
  Widget _buildPairingView(String deviceId) {
    // Формат данных для QR, который понимает Компаньон
    final qrData = jsonEncode({
      "device_uid": deviceId,
      "model": "MDD Watch Ultra", // Можно брать из device_info_plus
    });

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pairing Mode", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 20),
            Text("ID: $deviceId", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            const Text("Scan this code with Companion App", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () {
                // Симулируем получение конфига от телефона
                // Это сохранит настройки и переведет экран в режим "Monitoring"
                getIt<WatchRepository>().setRegistered(true);
                getIt<WatchRepository>().saveSettings(5, 30); // Чувствительность 5, таймер 30с
                getIt<HomeCubit>().refresh();
              },
              child: const Text("DEV: Force Pair"),
            ),
          ],
        ),
      ),
    );
  }

  // Экран активного мониторинга
  Widget _buildActiveView(BuildContext context, String deviceId) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Monitoring Active", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            Text("ID: $deviceId"),
            const SizedBox(height: 40),

            // Кнопка ручного SOS
            GestureDetector(
              onLongPress: () {
                // Долгое нажатие для теста падения
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmScreen()));
                // Сообщаем сервису, что это как будто падение
                FlutterBackgroundService().invoke('simulateFall');
              },
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: const Center(
                  child: Text("HOLD SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}