import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../core/services/ble_server_service.dart';
import '../../../data/repositories/watch_repository.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeUnregistered extends HomeState {
  final String deviceId;
  HomeUnregistered(this.deviceId);
}

class HomeDisconnected extends HomeState {
  final String deviceId;
  HomeDisconnected(this.deviceId);
}

class HomeConnected extends HomeState {
  final String deviceId;
  HomeConnected(this.deviceId);
}

@injectable
class HomeCubit extends Cubit<HomeState> {
  final WatchRepository _repository;
  final BleServerService _bleServerService;
  StreamSubscription? _connectionSub;

  bool _isConnected = false;

  HomeCubit(this._repository, this._bleServerService) : super(HomeInitial()) {
    _init();
  }

  void _init() {
    _connectionSub = _bleServerService.isConnectedStream.listen((isConnected) {
      // Если пришло событие от нативного слоя, обновляем
      setConnectionStatus(isConnected);
    });
    checkStatus();
  }

  // Читает данные из БД (используется при старте)
  void checkStatus() {
    final deviceId = _repository.getDeviceId();
    final isRegistered = _repository.isRegistered();
    _emitState(deviceId, isRegistered, _isConnected);
  }

  // Вызывается из UI при событии 'connectionUpdate'
  void setConnectionStatus(bool isConnected) {
    _isConnected = isConnected;
    // Просто перечитываем текущий статус регистрации из репозитория
    final deviceId = _repository.getDeviceId();
    final isRegistered = _repository.isRegistered();
    _emitState(deviceId, isRegistered, _isConnected);
  }

  // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
  // Вызывается из UI при событии 'refreshStatus'
  // Мы ДОВЕРЯЕМ value, а не читаем из базы, так как база в UI изоляте может быть устаревшей
  void setRegistered(bool value) {
    final deviceId = _repository.getDeviceId();

    // Если нам сказали, что мы зарегистрировались, значит мы и подключены
    if (value) {
      _isConnected = true;
      // Принудительно обновляем кэш в UI изоляте, чтобы при перезапуске было ок
      _repository.setRegistered(true);
    }

    _emitState(deviceId, value, _isConnected);
  }

  // Единая логика выбора состояния
  void _emitState(String deviceId, bool isRegistered, bool isConnected) {
    if (!isRegistered) {
      emit(HomeUnregistered(deviceId));
    } else {
      if (isConnected) {
        emit(HomeConnected(deviceId));
      } else {
        emit(HomeDisconnected(deviceId));
      }
    }
  }

  Future<void> resetRegistration() async {
    await _repository.setRegistered(false);
    _isConnected = false;
    checkStatus();
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    return super.close();
  }
}