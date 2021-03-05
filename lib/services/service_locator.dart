import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'console_service.dart';
import 'logging_service.dart';
import 'settings_service.dart';

final serviceLocator = GetIt.instance;

const String configFile = String.fromEnvironment('KNOWGO_SIMULATOR_CONFIG',
    defaultValue: 'config.yaml');

void setupServices() {
  serviceLocator.registerSingletonAsync<SettingsService>(() async {
    if (kIsWeb) {
      return SettingsService();
    } else {
      final config = File(configFile);
      // If the config file already exists, read settings from it
      if (config.existsSync()) {
        return SettingsService.fromYaml(config);
      }
      // Create new settings instance, and save to config file
      return SettingsService(config);
    }
  });

  if (kIsWeb) {
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
