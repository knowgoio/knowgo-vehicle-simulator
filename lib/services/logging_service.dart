import 'dart:io';

import 'package:intl/intl.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:path_provider/path_provider.dart';

abstract class LoggingService {
  void write(String msg);
}

class LoggingServiceImplementation extends LoggingService {
  final _settingsService = serviceLocator.get<SettingsService>();
  File? _logFile = null;

  LoggingServiceImplementation();

  Future<File> initLogFile() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final logDir = String.fromEnvironment('KNOWGO_VEHICLE_SIMULATOR_LOGS',
        defaultValue: appDocDir.path + '/knowgo_vehicle_simulator/logs');
    final logFile = File(logDir +
        '/Simulator-' +
        DateFormat('yyyy-MM-dd-H-m-s').format(DateTime.now()) +
        '.log');
    logFile.createSync(recursive: true);
    return logFile;
  }

  @override
  void write(String msg) async {
    if (_settingsService.loggingEnabled) {
      if (_logFile == null) {
        _logFile = await initLogFile();
      }

      _logFile!.writeAsStringSync(msg + '\n', mode: FileMode.append);
    }
  }
}
