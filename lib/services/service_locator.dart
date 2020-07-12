import 'package:get_it/get_it.dart';
import 'package:knowgo_simulator_desktop/services/logging_service.dart';

import 'console_service.dart';

final serviceLocator = GetIt.instance;

void setupServices() {
  serviceLocator
      .registerSingleton<LoggingService>(LoggingServiceImplementation());
  serviceLocator
      .registerSingleton<ConsoleService>(ConsoleServiceImplementation());
}
