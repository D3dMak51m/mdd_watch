class AppConstants {
  static const String baseUrl = 'https://your-api-server.com';

  // BLE UUIDs (Те же, что и в Компаньоне)
  static const String serviceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String sosCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  static const String ackCharacteristicUuid = '00002a38-0000-1000-8000-00805f9b34fb';
  static const String configCharacteristicUuid = '00002a39-0000-1000-8000-00805f9b34fb';

  // Prefs Keys
  static const String deviceUidKey = 'device_uid';
  static const String isRegisteredKey = 'is_registered';
  static const String fallSensitivityKey = 'fall_sensitivity';
}