import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

class ConsoleMessage {
  DateTime timestamp;
  String message;

  ConsoleMessage({@required this.timestamp, @required this.message});
}

abstract class ConsoleService extends ChangeNotifier {
  List<ConsoleMessage> get messages;
  void write(String msg);
  void clear();
}

class ConsoleServiceImplementation extends ConsoleService {
  List<ConsoleMessage> _messages = [];

  ConsoleServiceImplementation();

  @override
  List<ConsoleMessage> get messages => _messages;

  @override
  void write(String msg) {
    final consoleMessage =
        ConsoleMessage(timestamp: DateTime.now(), message: msg);

    _messages.add(consoleMessage);
    notifyListeners();
  }

  @override
  void clear() {
    _messages = [];
    notifyListeners();
  }
}
