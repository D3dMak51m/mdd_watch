class AppConstants {
  // TODO: Замените на реальный адрес вашего API
  static const String baseUrl = 'https://your-api-server.com';

  // --- BLE UUIDs ---
  // Основной сервис
  static const String serviceUuid = '0000180d-0000-1000-8000-00805f9b34fb';

  // Характеристики
  // Часы -> Телефон (Notify): Отправка тревоги и трекинга
  static const String sosCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb';

  // Телефон -> Часы (Write): Подтверждение получения тревоги
  static const String ackCharacteristicUuid = '00002a38-0000-1000-8000-00805f9b34fb';

  // Телефон -> Часы (Write): Настройка чувствительности и таймеров
  static const String configCharacteristicUuid = '00002a39-0000-1000-8000-00805f9b34fb';

  // --- SharedPreferences Keys ---
  static const String deviceUidKey = 'device_uid';
  static const String isRegisteredKey = 'is_registered';
  static const String fallSensitivityKey = 'fall_sensitivity';
  static const String sosTimeoutKey = 'sos_timeout';
}