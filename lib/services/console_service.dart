import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:meta/meta.dart';

class ConsoleMessage {
  DateTime timestamp;
  String message;

  ConsoleMessage({@required this.timestamp, @required this.message});

  @override
  String toString() {
    var timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    return '[$timeStr] $message';
  }
}

abstract class ConsoleService extends ChangeNotifier {
  List<ConsoleMessage> get messages;
  void write(String msg);
  void clear();
}

class ConsoleServiceImplementation extends ConsoleService {
  List<ConsoleMessage> _messages = [];
  var _logger;

  ConsoleServiceImplementation() {
    if (serviceLocator.isRegistered<LoggingService>()) {
      _logger = serviceLocator.get<LoggingService>();
    }
  }

  @override
  List<ConsoleMessage> get messages => _messages;

  @override
  void write(String msg) {
    final consoleMessage =
        ConsoleMessage(timestamp: DateTime.now(), message: msg);

    _messages.add(consoleMessage);
    if (_logger != null) {
      _logger.write(consoleMessage.toString());
    }

    notifyListeners();
  }

  @override
  void clear() {
    _messages = [];
    notifyListeners();
  }
}
