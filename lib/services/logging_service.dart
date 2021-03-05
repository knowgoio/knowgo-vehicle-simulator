import 'dart:io';

import 'package:intl/intl.dart';
import 'package:knowgo_vehicle_simulator/services.dart';

abstract class LoggingService {
  void write(String msg);
}

class LoggingServiceImplementation extends LoggingService {
  final _settingsService = serviceLocator.get<SettingsService>();
  final _logFile = File('Simulator-' +
      DateFormat('yyyy-MM-dd-H-m-s').format(DateTime.now()) +
      '.log');

  LoggingServiceImplementation();

  @override
  void write(String msg) {
    if (_settingsService.loggingEnabled) {
      _logFile.writeAsStringSync(msg + '\n', mode: FileMode.append);
    }
  }
}
