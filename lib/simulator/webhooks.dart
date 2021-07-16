import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:knowgo/api.dart' as knowgo;
import 'package:uuid/uuid.dart';

enum EventTrigger {
  none,
  automation_level_changed,
  journey_begin,
  journey_end,
  ignition_changed,
  location_changed,
  harsh_acceleration,
  harsh_braking
}

EventTrigger eventTriggerStringToEnum(String eventTrigger) {
  switch (eventTrigger) {
    case 'automation_level_changed':
      return EventTrigger.automation_level_changed;
    case 'journey_begin':
      return EventTrigger.journey_begin;
    case 'journey_end':
      return EventTrigger.journey_end;
    case 'ignition_changed':
      return EventTrigger.ignition_changed;
    case 'location_changed':
      return EventTrigger.location_changed;
    case 'harsh_acceleration':
      return EventTrigger.harsh_acceleration;
    case 'harsh_braking':
      return EventTrigger.harsh_braking;
  }

  // Unable to match value
  assert(false);

  return EventTrigger.none;
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

  static final _singleton = WebhookModel._internal();

  factory WebhookModel() {
    return _singleton;
  }

  WebhookModel._internal()
      : _triggers = [
          EventTrigger.journey_begin,
          EventTrigger.journey_end,
          EventTrigger.ignition_changed,
          EventTrigger.location_changed,
          EventTrigger.harsh_acceleration,
          EventTrigger.harsh_braking,
        ];

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
  }

  void removeSubscription(String subscriptionId) {
    _subscriptions.removeWhere(
        (subscription) => subscription.subscriptionId == subscriptionId);
  }

  void updateSubscription(WebhookSubscription subscription) {
    removeSubscription(subscription.subscriptionId);
    addSubscription(subscription);
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
      nested['pedal_start_position'] =
          prevState.acceleratorPedalPosition.floor();
      nested['pedal_end_position'] = newState.acceleratorPedalPosition.floor();
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['harsh_acceleration'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
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
      nested['pedal_start_position'] = prevState.brakePedalPosition.floor();
      nested['pedal_end_position'] = newState.brakePedalPosition.floor();
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['harsh_braking'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
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
      nested['ignition_start_state'] = describeEnum(prevState.ignitionStatus);
      nested['ignition_end_state'] = describeEnum(newState.ignitionStatus);
      nested['timestamp'] = newState.timestamp.toIso8601String();
      payload['ignition_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
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
      nested['timestamp'] = event.timestamp.toIso8601String();
      payload['location_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
    });
  }

  void _processAutomationLevelChange(knowgo.Auto info, knowgo.Event event) {
    var subscribers = _subscriptions.where((subscription) =>
        subscription.triggers.contains(EventTrigger.automation_level_changed));
    subscribers.forEach((subscriber) {
      final url = Uri.parse(subscriber.notificationUrl);
      Map<String, dynamic> payload = {};
      Map<String, dynamic> nested = {};
      nested['vehicleId'] = info.autoID;
      nested['level'] = event.automationLevel;
      nested['timestamp'] = event.timestamp.toIso8601String();
      payload['automation_level_changed'] = nested;
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
    });
  }

  void processWebhooks(
      knowgo.Auto info, knowgo.Event prevState, knowgo.Event newState) {
    if (prevState.longitude != newState.longitude ||
        prevState.latitude != newState.latitude) {
      _processLocationChange(info, newState);
    }

    if (prevState.automationLevel != newState.automationLevel) {
      _processAutomationLevelChange(info, newState);
    }

    if (prevState.ignitionStatus != newState.ignitionStatus) {
      _processIgnitionStatusChange(info, prevState, newState);
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
