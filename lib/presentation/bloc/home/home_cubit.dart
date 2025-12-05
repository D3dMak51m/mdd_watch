import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
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

  // Локальное состояние подключения
  bool _isConnected = false;

  HomeCubit(this._repository) : super(HomeInitial()) {
    // Вызываем проверку при создании
    checkStatus();
  }

  // --- ИСПРАВЛЕНИЕ: Метод сделан публичным (убрано подчеркивание) ---
  void checkStatus() {
    final deviceId = _repository.getDeviceId();
    final isRegistered = _repository.isRegistered();

    if (!isRegistered) {
      emit(HomeUnregistered(deviceId));
    } else {
      if (_isConnected) {
        emit(HomeConnected(deviceId));
      } else {
        emit(HomeDisconnected(deviceId));
      }
    }
  }

  // Вызывается из UI при событии 'connectionUpdate'
  void setConnectionStatus(bool isConnected) {
    _isConnected = isConnected;
    checkStatus(); // Используем публичный метод
  }

  // Вызывается из UI при событии 'refreshStatus'
  void setRegistered(bool value) {
    if (value) {
      // Если только что пришел конфиг, значит мы подключены
      _isConnected = true;
    }
    checkStatus(); // Используем публичный метод
  }

  Future<void> resetRegistration() async {
    await _repository.setRegistered(false);
    _isConnected = false;
    checkStatus(); // Используем публичный метод
  }
}