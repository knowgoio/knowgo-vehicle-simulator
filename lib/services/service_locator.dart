import 'package:get_it/get_it.dart';

import 'console_service.dart';

final serviceLocator = GetIt.instance;

void setupServices() {
  serviceLocator
      .registerSingleton<ConsoleService>(ConsoleServiceImplementation());
}
