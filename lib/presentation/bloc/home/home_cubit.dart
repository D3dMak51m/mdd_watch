import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../data/repositories/watch_repository.dart';

abstract class HomeState {}
class HomeInitial extends HomeState {}
class HomeUnregistered extends HomeState {
  final String deviceId;
  HomeUnregistered(this.deviceId);
}
class HomeRegistered extends HomeState {
  final String deviceId;
  HomeRegistered(this.deviceId);
}

@injectable
class HomeCubit extends Cubit<HomeState> {
  final WatchRepository _repository;

  HomeCubit(this._repository) : super(HomeInitial()) {
    checkStatus();
  }

  void checkStatus() {
    final deviceId = _repository.getDeviceId();
    final isRegistered = _repository.isRegistered();

    if (isRegistered) {
      emit(HomeRegistered(deviceId));
    } else {
      emit(HomeUnregistered(deviceId));
    }
  }

  // Вызывается, когда сервис сообщает об изменениях
  void refresh() => checkStatus();
}