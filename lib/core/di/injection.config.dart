// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../data/repositories/watch_repository.dart' as _i277;
import '../../presentation/bloc/home/home_cubit.dart' as _i882;
import '../services/background_service.dart' as _i879;
import '../services/ble_server_service.dart' as _i216;
import '../services/fall_detection_service.dart' as _i685;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i879.AppBackgroundService>(
      () => _i879.AppBackgroundService(),
    );
    gh.lazySingleton<_i216.BleServerService>(() => _i216.BleServerService());
    gh.lazySingleton<_i685.FallDetectionService>(
      () => _i685.FallDetectionService(),
    );
    gh.lazySingleton<_i277.WatchRepository>(
      () => _i277.WatchRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i882.HomeCubit>(
      () => _i882.HomeCubit(gh<_i277.WatchRepository>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
