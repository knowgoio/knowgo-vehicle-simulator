import 'dart:collection';

import 'package:flutter/material.dart';

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
  static final _singleton = VehicleNotificationModel._internal();

  factory VehicleNotificationModel() {
    return _singleton;
  }

  VehicleNotificationModel._internal();

  UnmodifiableListView<VehicleNotification> get notifications =>
      UnmodifiableListView(_notifications);

  void pushAll(List<VehicleNotification> notifications) {
    _notifications.addAll(notifications);
    notifyListeners();
  }

  void push(VehicleNotification notification) {
    _notifications.add(notification);
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
