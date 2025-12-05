import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/di/injection.dart';
import '../bloc/home/home_cubit.dart';
import 'alarm_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeCubit _homeCubit;

  @override
  void initState() {
    super.initState();

    // 1. Получаем кубит из DI
    _homeCubit = getIt<HomeCubit>();

    final service = FlutterBackgroundService();

    // 2. Подписываемся на события сервиса
    service.on('refreshStatus').listen((event) {
      print("UI: Received refreshStatus event: $event"); // Лог для отладки
      if (event != null && event['isRegistered'] == true) {
        _homeCubit.setRegistered(true);
      }
    });

    service.on('connectionUpdate').listen((event) {
      print("UI: Received connectionUpdate event: $event"); // Лог для отладки
      if (event != null) {
        final bool isConnected = event['isConnected'] ?? false;
        _homeCubit.setConnectionStatus(isConnected);
      }
    });

    // 3. Дополнительная проверка при старте (на случай если сервис уже работает)
    // Это заставит кубит перечитать состояние из репозитория
    _homeCubit.checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _homeCubit,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              if (state is HomeUnregistered) {
                return _buildPairingView(state.deviceId);
              } else if (state is HomeDisconnected) {
                return _buildDisconnectedView(context, state.deviceId);
              } else if (state is HomeConnected) {
                return _buildActiveView(context, state.deviceId);
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  // 1. Экран QR (не привязан)
  Widget _buildPairingView(String deviceId) {
    final qrData = jsonEncode({"device_uid": deviceId, "model": "MDD Watch"});

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
              child: QrImageView(data: qrData, version: QrVersions.auto, size: 180.0),
            ),
            const SizedBox(height: 20),
            Text("ID: $deviceId", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Scan with Companion App to link", textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Экран Ожидания (привязан, но нет связи)
  Widget _buildDisconnectedView(BuildContext context, String deviceId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_searching, size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          const Text("Waiting for phone...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Device is linked but disconnected"),
          const SizedBox(height: 40),

          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text("Unlink / Reset"),
            onPressed: () {
              _homeCubit.resetRegistration();
            },
          ),
        ],
      ),
    );
  }

  // 3. Экран Активен (подключен)
  Widget _buildActiveView(BuildContext context, String deviceId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            "Monitoring Active",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 10),
          const Text("Connected to Companion"),
          const SizedBox(height: 40),

          GestureDetector(
            onLongPress: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmScreen()));
              FlutterBackgroundService().invoke('simulateFall');
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 4),
              ),
              child: const Center(
                child: Text(
                  "HOLD SOS",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}