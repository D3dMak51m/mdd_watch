import 'dart:async';
import 'dart:math';
import 'package:injectable/injectable.dart';
import 'package:sensors_plus/sensors_plus.dart';

@lazySingleton
class FallDetectionService {
  StreamSubscription? _subscription;
  final _fallController = StreamController<void>.broadcast();

  // Stream, который эмитит событие при обнаружении падения
  Stream<void> get onFallDetected => _fallController.stream;

  // Порог срабатывания (в m/s^2).
  // 3G ~= 29.4 m/s^2. Для тестов можно поставить меньше (например, 20).
  static const double _fallThreshold = 25.0;

  // Задержка после падения, чтобы не спамить событиями (debounce)
  bool _isCoolingDown = false;

  void startMonitoring() {
    _subscription?.cancel();

    // UserAccelerometerEvents - это ускорение без учета гравитации.
    // Но для удара лучше использовать сырой AccelerometerEvent (с гравитацией),
    // так как удар - это резкое изменение общей силы.
    _subscription = accelerometerEventStream().listen((event) {
      if (_isCoolingDown) return;

      final double gForce = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

      if (gForce > _fallThreshold) {
        _triggerFall();
      }
    });

    print("Fall Detection: Started");
  }

  void stopMonitoring() {
    _subscription?.cancel();
    print("Fall Detection: Stopped");
  }

  void _triggerFall() {
    print("Fall Detection: FALL DETECTED! (Force > $_fallThreshold)");
    _fallController.add(null);

    _isCoolingDown = true;
    // Блокируем повторное срабатывание на 5 секунд
    Future.delayed(const Duration(seconds: 5), () {
      _isCoolingDown = false;
    });
  }
}