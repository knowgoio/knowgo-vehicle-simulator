import 'dart:io';

import 'package:get_it/get_it.dart';

import 'console_service.dart';
import 'logging_service.dart';
import 'settings_service.dart';

final serviceLocator = GetIt.instance;

void setupServices(String configFile) {
  serviceLocator.registerSingletonAsync<SettingsService>(() async {
    final config = File(configFile);
    // If the config file already exists, read settings from it
    if (config.existsSync()) {
      return SettingsService.fromYaml(config);
    }
    // Create new settings instance, and save to config file
    return SettingsService(config);
  });

  serviceLocator.registerSingletonWithDependencies<LoggingService>(
    () => LoggingServiceImplementation(),
    dependsOn: [SettingsService],
  );

  serviceLocator.registerSingletonWithDependencies<ConsoleService>(
    () => ConsoleServiceImplementation(),
    dependsOn: [LoggingService],
  );
}
