import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:prometheus_client/prometheus_client.dart';

class VehicleNotification {
  final String text;

  VehicleNotification({required this.text});

  VehicleNotification.fromJson(Map<String, dynamic> json) : text = json['text'];

  Map<String, dynamic> toJson() => {
        'text': text,
      };
}

class VehicleNotificationModel extends ChangeNotifier {
  final List<VehicleNotification> _notifications = [];
  final _numNotificationsSent = Counter(
      name: 'simulator_notifications_sent_total',
      help: 'Total number of notifications sent to the simulator.')
    ..register();

  static final _singleton = VehicleNotificationModel._internal();

  factory VehicleNotificationModel() {
    return _singleton;
  }

  VehicleNotificationModel._internal();

  UnmodifiableListView<VehicleNotification> get notifications =>
      UnmodifiableListView(_notifications);

  void pushAll(List<VehicleNotification> notifications) {
    _notifications.addAll(notifications);
    _numNotificationsSent.inc(notifications.length.toDouble());
    notifyListeners();
  }

  void push(VehicleNotification notification) {
    _notifications.add(notification);
    _numNotificationsSent.inc();
    notifyListeners();
  }

  VehicleNotification? pop() {
    if (_notifications.isNotEmpty) {
      var notification = _notifications.removeLast();
      notifyListeners();
      return notification;
    }

    return null;
  }

  void clear() {
    _notifications.clear();
  }
}
