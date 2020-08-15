import 'package:get_it/get_it.dart';

import 'console_service.dart';
import 'logging_service.dart';
import 'settings_service.dart';

final serviceLocator = GetIt.instance;

void setupServices() {
  serviceLocator.registerSingletonAsync<SettingsService>(() async {
    final settingsService = SettingsService();
    await settingsService.init();
    return settingsService;
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
