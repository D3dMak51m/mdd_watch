import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

@lazySingleton
class WatchRepository {
  final SharedPreferences _prefs;

  WatchRepository(this._prefs);

  /// Возвращает уникальный ID устройства.
  /// Если ID еще нет, генерирует новый и сохраняет его.
  String getDeviceId() {
    String? uid = _prefs.getString(AppConstants.deviceUidKey);
    if (uid == null) {
      // Генерируем короткий UUID для удобства (в продакшене лучше использовать полный)
      uid = 'watch_${const Uuid().v4().substring(0, 8)}';
      _prefs.setString(AppConstants.deviceUidKey, uid);
    }
    return uid;
  }

  /// Проверяет, привязаны ли часы к телефону/серверу
  bool isRegistered() {
    return _prefs.getBool(AppConstants.isRegisteredKey) ?? false;
  }

  /// Устанавливает статус регистрации
  Future<void> setRegistered(bool value) async {
    await _prefs.setBool(AppConstants.isRegisteredKey, value);
  }

  /// Сохраняет настройки, полученные от телефона
  Future<void> saveSettings(int sensitivity, int timeout) async {
    await _prefs.setInt(AppConstants.fallSensitivityKey, sensitivity);
    await _prefs.setInt(AppConstants.sosTimeoutKey, timeout);
  }

  /// Получает текущую чувствительность (по умолчанию 5)
  int getSensitivity() {
    return _prefs.getInt(AppConstants.fallSensitivityKey) ?? 5;
  }

  /// Получает текущий таймаут обратного отсчета (по умолчанию 30 сек)
  int getSosTimeout() {
    return _prefs.getInt(AppConstants.sosTimeoutKey) ?? 30;
  }
}