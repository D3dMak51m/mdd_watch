import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @preResolve // Важно: ждем инициализации
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}