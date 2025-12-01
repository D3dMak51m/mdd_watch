import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class BleServerService {
  static const MethodChannel _methodChannel = MethodChannel('com.mdd.watch/ble_server');
  static const EventChannel _eventChannel = EventChannel('com.mdd.watch/ble_events');

  final StreamController<Map<String, dynamic>> _bleEventsController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get bleEvents => _bleEventsController.stream;

  BleServerService() {
    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final Map<String, dynamic> castedEvent = Map<String, dynamic>.from(event);
          _bleEventsController.add(castedEvent);
        }
      },
      onError: (error) {
        print("Error receiving BLE event: $error");
      },
    );
  }

  /// Запуск сервера и рекламы (Advertising)
  Future<void> startServer(String deviceName) async {
    try {
      await _methodChannel.invokeMethod('startServer', {'name': deviceName});
    } on PlatformException catch (e) {
      print("Failed to start BLE Server: '${e.message}'.");
    }
  }

  /// Остановка сервера
  Future<void> stopServer() async {
    try {
      await _methodChannel.invokeMethod('stopServer');
    } on PlatformException catch (e) {
      print("Failed to stop BLE Server: '${e.message}'.");
    }
  }

  /// Отправка данных SOS (обновление характеристики)
  Future<void> updateSosCharacteristic(Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      await _methodChannel.invokeMethod('updateSos', {'payload': jsonString});
    } on PlatformException catch (e) {
      print("Failed to update SOS: '${e.message}'.");
    }
  }
}
