import 'dart:io';

import 'package:intl/intl.dart';

abstract class LoggingService {
  void write(String msg);
}

class LoggingServiceImplementation extends LoggingService {
  final _logFile = File('Simulator-' +
      DateFormat('yyyy-MM-dd-H-m-s').format(DateTime.now()) +
      '.log');

  LoggingServiceImplementation();

  @override
  void write(String msg) {
    _logFile.writeAsStringSync(msg + '\n', mode: FileMode.append);
  }
}
