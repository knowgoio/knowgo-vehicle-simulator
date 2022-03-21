import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:knowgo/api.dart' as knowgo;
import 'package:prometheus_client/prometheus_client.dart';
import 'package:uuid/uuid.dart';

enum EventTrigger {
  none,
  automation_level_changed,
  driver_changed,
  journey_begin,
  journey_end,
  ignition_changed,
  location_changed,
  harsh_acceleration,
  harsh_braking
}

final Map<EventTrigger, String> _eventTriggerDescriptionMap = {
  EventTrigger.automation_level_changed:
      'Triggered when the SAE J3016 level of driving automation changes',
  EventTrigger.driver_changed: 'Triggered when the active Driver is changed',
  EventTrigger.journey_begin: 'Triggered when a new Journey is started',
  EventTrigger.journey_end: 'Triggered when a Journey is completed',
  EventTrigger.location_changed:
      'Triggered each time the vehicle location changes',
  EventTrigger.ignition_changed:
      'Triggered any time the ignition status changes',
  EventTrigger.harsh_acceleration:
      'Triggered any time a harsh acceleration event is detected',
  EventTrigger.harsh_braking:
      'Triggered any time a harsh braking event is detected',
};

EventTrigger eventTriggerStringToEnum(String eventTrigger) {
  return EventTrigger.values.singleWhere(
      (trigger) => eventTrigger == describeEnum(trigger),
      orElse: () => EventTrigger.none);
}

extension EventTriggerDescription on EventTrigger {
  String? get description {
    return _eventTriggerDescriptionMap[this];
  }
}

final _uuidGenerator = Uuid();

class WebhookSubscription {
  final List<EventTrigger> triggers;
  final String notificationUrl;
  String subscriptionId;

  WebhookSubscription({required this.triggers, required this.notificationUrl})
      : subscriptionId = _uuidGenerator.v4();

  WebhookSubscription.fromExisting(
      {required this.subscriptionId,
      required this.triggers,
      required this.notificationUrl})
      : assert(subscriptionId.isNotEmpty),
        assert(triggers.length > 0),
        assert(notificationUrl.isNotEmpty);

  WebhookSubscription.fromJson(Map<String, dynamic> json)
      : triggers = (json['webhooks'] as List)
            .cast<String>()
            .map((t) => eventTriggerStringToEnum(t))
            .toList(),
        notificationUrl = json['notificationUrl'],
        subscriptionId = json['subscriptionId'] ?? _uuidGenerator.v4();

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['subscriptionId'] = subscriptionId;
    json['webhooks'] = triggers.map((t) => describeEnum(t)).toList();
    json['notificationUrl'] = notificationUrl;
    return json;
  }

  @override
  String toString() {
    return 'WebhookSubscription[subscriptionId=$subscriptionId, webhooks=$triggers, notificationUrl=$notificationUrl]';
  }
}

class WebhookModel extends ChangeNotifier {
  final List<EventTrigger> _triggers;
  final List<WebhookSubscription> _subscriptions = [];

  final _numSubscriptions = Gauge(
      name: 'simulator_webhook_subscriptions_total',
      help: 'Total number of active webhook subscriptions.')
    ..register();
  final _numWebhooksFired = Counter(
      name: 'simulator_webhooks_fired_total',
      help: 'Total number of webhooks that have been fired.')
    ..register();

  static final _singleton = WebhookModel._internal();

  factory WebhookModel() {
    return _singleton;
  }

  // Valid triggers are all EventTrigger values except 'none'
  WebhookModel._internal() : _triggers = EventTrigger.values.sublist(1);

  UnmodifiableListView<EventTrigger> get triggers =>
      UnmodifiableListView(_triggers);

  void enableEventTrigger(EventTrigger eventTrigger) {
    if (!_triggers.contains(eventTrigger)) {
      _triggers.add(eventTrigger);
      notifyListeners();
    }
  }

  void disableEventTrigger(EventTrigger eventTrigger) {
    if (_triggers.contains(eventTrigger)) {
      _triggers.remove(eventTrigger);
      notifyListeners();
    }
  }

  UnmodifiableListView<WebhookSubscription> get subscriptions =>
      UnmodifiableListView(_subscriptions);

  void addSubscription(WebhookSubscription subscription) {
    _subscriptions.add(subscription);
    _numSubscriptions.inc();
  }

  void removeSubscription(String subscriptionId) {
    _subscriptions.removeWhere(
        (subscription) => subscription.subscriptionId == subscriptionId);
    _numSubscriptions.dec();
  }

  void updateSubscription(WebhookSubscription subscription) {
    removeSubscription(subscription.subscriptionId);
    addSubscription(subscription);
  }

  void _processDriverChanged(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.driver_changed));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['old_driverId'] = prevState.driverID;
      nested['new_driverId'] = newState.driverID;
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['driver_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processHarshAcceleration(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.harsh_acceleration));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['driverId'] = newState.driverID;
      nested['pedal_start_position'] =
          prevState.acceleratorPedalPosition.floor();
      nested['pedal_end_position'] = newState.acceleratorPedalPosition.floor();
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['harsh_acceleration'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processHarshBraking(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.harsh_braking));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['driverId'] = info.driverID;
      nested['pedal_start_position'] = prevState.brakePedalPosition.floor();
      nested['pedal_end_position'] = newState.brakePedalPosition.floor();
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['harsh_braking'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processIgnitionStatusChange(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.ignition_changed));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['driverId'] = newState.driverID;
      nested['ignition_start_state'] = describeEnum(prevState.ignitionStatus);
      nested['ignition_end_state'] = describeEnum(newState.ignitionStatus);
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['ignition_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processJourneyBegin(knowgo.Auto info, knowgo.Event event) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.journey_begin));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['driverId'] = event.driverID;
      nested['latitude'] = event.latitude;
      nested['longitude'] = event.longitude;
      nested['bearing'] = event.bearing.toInt();
      nested['timestamp'] = event.timestamp.toIso8601String();
      payload['journey_begin'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processJourneyEnd(knowgo.Auto info, knowgo.Event event) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.journey_end));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['driverId'] = event.driverID;
      nested['latitude'] = event.latitude;
      nested['longitude'] = event.longitude;
      nested['bearing'] = event.bearing.toInt();
      nested['timestamp'] = event.timestamp.toIso8601String();
      payload['journey_end'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processLocationChange(knowgo.Auto info, knowgo.Event event) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.location_changed));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['longitude'] = event.longitude;
      nested['latitude'] = event.latitude;
      nested['bearing'] = event.bearing.toInt();
      nested['timestamp'] = event.timestamp.toIso8601String();
      payload['location_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void _processAutomationLevelChange(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.automation_level_changed));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['old_level'] = prevState.automationLevel;
      nested['new_level'] = newState.automationLevel;
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['automation_level_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      _numWebhooksFired.inc();
    });
  }

  void processWebhooks(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    if (prevState.longitude != newState.longitude ||
        prevState.latitude != newState.latitude ||
        prevState.bearing != newState.bearing) {
      _processLocationChange(info, newState);
    }

    if (prevState.automationLevel != newState.automationLevel) {
      _processAutomationLevelChange(info, prevState, newState);
    }

    if (prevState.driverID != newState.driverID) {
      _processDriverChanged(info, prevState, newState);
    }

    if (prevState.ignitionStatus != newState.ignitionStatus) {
      if (newState.ignitionStatus == knowgo.IgnitionStatus.run) {
        _processJourneyBegin(info, newState);
      }

      _processIgnitionStatusChange(info, prevState, newState);

      if (newState.ignitionStatus == knowgo.IgnitionStatus.off) {
        _processJourneyEnd(info, newState);
      }
    }

    if ((newState.acceleratorPedalPosition -
            prevState.acceleratorPedalPosition) >=
        65) {
      _processHarshAcceleration(info, prevState, newState);
    }

    if ((newState.brakePedalPosition - prevState.brakePedalPosition) >= 65) {
      _processHarshBraking(info, prevState, newState);
    }
  }
}
