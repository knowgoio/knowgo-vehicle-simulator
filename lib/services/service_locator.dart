import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_platform/universal_platform.dart';

import 'console_service.dart';
import 'logging_service.dart';
import 'settings_service.dart';

final serviceLocator = GetIt.instance;

void setupServices() {
  serviceLocator.registerSingletonAsync<SettingsService>(() async {
    // TODO: Investigate why this is crashing on the Pixel C tablet
    if (UniversalPlatform.isWeb || UniversalPlatform.isAndroid) {
      return SettingsService();
    } else {
      final configDir = await getApplicationDocumentsDirectory();
      var configFile = String.fromEnvironment('KNOWGO_VEHICLE_SIMULATOR_CONFIG',
          defaultValue:
              configDir.path + '/knowgo_vehicle_simulator/config.yaml');
      var config = File(configFile);

      // If the config file already exists, read settings from it
      if (config.existsSync()) {
        return SettingsService.fromYaml(config);
      }

      // Create new settings instance, and save to config file
      config.createSync(recursive: true);
      return SettingsService(config);
    }
  });

  if (UniversalPlatform.isWeb) {
    serviceLocator
        .registerSingleton<ConsoleService>(ConsoleServiceImplementation());
  } else {
    serviceLocator.registerSingletonWithDependencies<LoggingService>(
      () => LoggingServiceImplementation(),
      dependsOn: [SettingsService],
    );

    serviceLocator.registerSingletonWithDependencies<ConsoleService>(
      () => ConsoleServiceImplementation(),
      dependsOn: [LoggingService],
    );
  }
}
